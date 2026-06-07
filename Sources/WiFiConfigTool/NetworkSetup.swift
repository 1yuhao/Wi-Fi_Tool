import Foundation

struct CommandResult: Sendable {
    var stdout: String
    var stderr: String
    var exitCode: Int32
}

enum NetworkSetupError: LocalizedError {
    case commandFailed(executable: String, arguments: [String], status: Int32, stdout: String, stderr: String)
    case wifiServiceNotFound
    case administratorAuthorizationCancelled

    var errorDescription: String? {
        switch self {
        case let .commandFailed(executable, arguments, status, stdout, stderr):
            let command = ([executable] + arguments).joined(separator: " ")
            let output = [stdout.trimmed, stderr.trimmed].filter { !$0.isEmpty }.joined(separator: "\n")
            return "\(command) failed with status \(status)\(output.isEmpty ? "" : ":\n\(output)")"
        case .wifiServiceNotFound:
            return "No Wi-Fi network service was found on this Mac."
        case .administratorAuthorizationCancelled:
            return "Administrator authorization was cancelled."
        }
    }
}

enum NetworkSetup {
    static func currentStatus() async throws -> WiFiStatus {
        let service = try await wifiNetworkService()
        async let ssid = currentSSID(deviceName: service.deviceName)
        async let info = serviceInfo(serviceName: service.serviceName)
        async let dns = dnsServers(serviceName: service.serviceName)

        var status = try await info
        status.serviceName = service.serviceName
        status.deviceName = service.deviceName
        status.currentSSID = try await ssid
        status.dnsServers = try await dns
        return status
    }

    static func apply(_ desired: DesiredNetworkConfiguration, serviceName: String) async throws {
        switch desired {
        case let .manual(settings):
            let command = [
                "/usr/sbin/networksetup -setmanual",
                shellQuote(serviceName),
                shellQuote(settings.ipAddress.trimmed),
                shellQuote(settings.subnetMask.trimmed),
                shellQuote(settings.router.trimmed)
            ].joined(separator: " ")

            let dnsCommand = dnsCommand(serviceName: serviceName, servers: settings.dnsServers)
            try await runAdministratorCommand([command, dnsCommand].joined(separator: " && "))

        case .dhcp:
            let command = [
                "/usr/sbin/networksetup -setdhcp",
                shellQuote(serviceName)
            ].joined(separator: " ")
            try await runAdministratorCommand(command)
        }
    }

    private static func wifiNetworkService() async throws -> WiFiNetworkService {
        let hardwareOutput = try await run("/usr/sbin/networksetup", ["-listallhardwareports"]).stdout
        let wifiDevice = parseWiFiDevice(fromHardwarePorts: hardwareOutput)

        let serviceOrder = try await run("/usr/sbin/networksetup", ["-listnetworkserviceorder"]).stdout
        if let service = parseServiceOrder(serviceOrder, wifiDevice: wifiDevice) {
            return service
        }

        let servicesOutput = try await run("/usr/sbin/networksetup", ["-listallnetworkservices"]).stdout
        if let fallbackName = parseWiFiServiceName(fromServices: servicesOutput) {
            return WiFiNetworkService(serviceName: fallbackName, deviceName: wifiDevice ?? "en0")
        }

        throw NetworkSetupError.wifiServiceNotFound
    }

    private static func currentSSID(deviceName: String) async throws -> String? {
        let result = try await run("/usr/sbin/networksetup", ["-getairportnetwork", deviceName])
        let output = result.stdout.trimmed
        if output.localizedCaseInsensitiveContains("not associated") {
            return nil
        }

        let prefix = "Current Wi-Fi Network:"
        if output.hasPrefix(prefix) {
            return output.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return output.isEmpty ? nil : output
    }

    private static func serviceInfo(serviceName: String) async throws -> WiFiStatus {
        let output = try await run("/usr/sbin/networksetup", ["-getinfo", serviceName]).stdout
        let method: IPConfigurationMethod
        if output.localizedCaseInsensitiveContains("DHCP Configuration") {
            method = .dhcp
        } else if output.localizedCaseInsensitiveContains("Manual Configuration") {
            method = .manual
        } else {
            method = .unknown
        }

        return WiFiStatus(
            serviceName: serviceName,
            deviceName: nil,
            currentSSID: nil,
            method: method,
            ipAddress: parseValue(named: "IP address", in: output),
            subnetMask: parseValue(named: "Subnet mask", in: output),
            router: parseValue(named: "Router", in: output),
            dnsServers: []
        )
    }

    private static func dnsServers(serviceName: String) async throws -> [String] {
        let output = try await run("/usr/sbin/networksetup", ["-getdnsservers", serviceName]).stdout
        if output.localizedCaseInsensitiveContains("aren't any DNS Servers") {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed }
            .filter { !$0.isEmpty }
    }

    private static func runAdministratorCommand(_ shellCommand: String) async throws {
        let script = #"do shell script "\#(appleScriptEscaped(shellCommand))" with administrator privileges"#
        do {
            _ = try await run("/usr/bin/osascript", ["-e", script])
        } catch let error as NetworkSetupError {
            if error.errorDescription?.localizedCaseInsensitiveContains("User canceled") == true
                || error.errorDescription?.localizedCaseInsensitiveContains("cancelled") == true {
                throw NetworkSetupError.administratorAuthorizationCancelled
            }
            throw error
        }
    }

    private static func dnsCommand(serviceName: String, servers: [String]) -> String {
        let values = servers.isEmpty ? ["Empty"] : servers.map(shellQuote)
        return (["/usr/sbin/networksetup -setdnsservers", shellQuote(serviceName)] + values).joined(separator: " ")
    }

    private static func run(_ executable: String, _ arguments: [String]) async throws -> CommandResult {
        try await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            try process.run()
            process.waitUntilExit()

            let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let result = CommandResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)

            guard result.exitCode == 0 else {
                throw NetworkSetupError.commandFailed(
                    executable: executable,
                    arguments: arguments,
                    status: result.exitCode,
                    stdout: result.stdout,
                    stderr: result.stderr
                )
            }

            return result
        }.value
    }

    private static func parseWiFiDevice(fromHardwarePorts output: String) -> String? {
        let blocks = output.components(separatedBy: "\n\n")
        for block in blocks {
            let lines = block.split(whereSeparator: \.isNewline).map(String.init)
            let hardwarePort = lines.first { $0.hasPrefix("Hardware Port:") }?
                .replacingOccurrences(of: "Hardware Port:", with: "")
                .trimmed
            let device = lines.first { $0.hasPrefix("Device:") }?
                .replacingOccurrences(of: "Device:", with: "")
                .trimmed

            if let hardwarePort, hardwarePort.localizedCaseInsensitiveContains("Wi-Fi") {
                return device
            }
        }

        return nil
    }

    private static func parseServiceOrder(_ output: String, wifiDevice: String?) -> WiFiNetworkService? {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        var pendingServiceName: String?

        for rawLine in lines {
            let line = rawLine.trimmed
            if line.hasPrefix("("), let closingIndex = line.firstIndex(of: ")") {
                let nameStart = line.index(after: closingIndex)
                pendingServiceName = String(line[nameStart...]).trimmed.strippingDisabledMarker
            } else if line.hasPrefix("(Hardware Port:") {
                let hardwarePort = parseParenthesizedValue(named: "Hardware Port", in: line)
                let device = parseParenthesizedValue(named: "Device", in: line)

                guard let serviceName = pendingServiceName else {
                    continue
                }

                if let wifiDevice, device == wifiDevice {
                    return WiFiNetworkService(serviceName: serviceName, deviceName: wifiDevice)
                }

                if hardwarePort?.localizedCaseInsensitiveContains("Wi-Fi") == true {
                    return WiFiNetworkService(serviceName: serviceName, deviceName: device ?? wifiDevice ?? "en0")
                }
            }
        }

        return nil
    }

    private static func parseWiFiServiceName(fromServices output: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmed.strippingDisabledMarker }
            .first { $0.localizedCaseInsensitiveContains("Wi-Fi") }
    }

    private static func parseValue(named name: String, in output: String) -> String? {
        output
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .first { $0.localizedCaseInsensitiveContains("\(name):") }?
            .components(separatedBy: ":")
            .dropFirst()
            .joined(separator: ":")
            .trimmed
            .nilIfEmpty
    }

    private static func parseParenthesizedValue(named name: String, in line: String) -> String? {
        let trimmedLine = line.trimmingCharacters(in: CharacterSet(charactersIn: "()"))
        let parts = trimmedLine.split(separator: ",").map { String($0).trimmed }
        return parts.first { $0.hasPrefix("\(name):") }?
            .replacingOccurrences(of: "\(name):", with: "")
            .trimmed
            .nilIfEmpty
    }

    private static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }

    private static func appleScriptEscaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }

    var strippingDisabledMarker: String {
        hasPrefix("*") ? String(dropFirst()).trimmed : self
    }
}
