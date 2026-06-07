import Foundation

enum IPConfigurationMethod: String, Sendable {
    case dhcp = "DHCP"
    case manual = "Manual"
    case unknown = "Unknown"

    var displayName: String {
        switch self {
        case .dhcp:
            "DHCP"
        case .manual:
            "手动 IP"
        case .unknown:
            "未知"
        }
    }
}

enum WiFiProfileMode: String, CaseIterable, Codable, Identifiable, Sendable {
    case manual
    case dhcp

    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .manual:
            "手动 IP"
        case .dhcp:
            "DHCP"
        }
    }

    var systemImage: String {
        switch self {
        case .manual:
            "network"
        case .dhcp:
            "network"
        }
    }
}

enum FeedbackKind: Sendable {
    case info
    case success
    case warning
    case error
}

struct WiFiProfile: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var ssid: String
    var mode: WiFiProfileMode
    var ipAddress: String
    var subnetMask: String
    var router: String
    var dnsServersText: String

    static func makeDefaultManual() -> WiFiProfile {
        WiFiProfile(
            id: UUID(),
            name: "家庭 Wi-Fi",
            ssid: "",
            mode: .manual,
            ipAddress: "192.168.1.20",
            subnetMask: "255.255.255.0",
            router: "192.168.1.1",
            dnsServersText: "1.1.1.1, 8.8.8.8"
        )
    }

    static func makeDefaultDHCP() -> WiFiProfile {
        WiFiProfile(
            id: UUID(),
            name: "新配置档",
            ssid: "",
            mode: .dhcp,
            ipAddress: "",
            subnetMask: "",
            router: "",
            dnsServersText: ""
        )
    }

    var displayName: String {
        if !name.trimmed.isEmpty {
            return name.trimmed
        }

        if !ssid.trimmed.isEmpty {
            return ssid.trimmed
        }

        return "未命名配置档"
    }

    var usesDefaultName: Bool {
        let value = name.trimmed
        return value.isEmpty
            || value == "家庭 Wi-Fi"
            || value == "新配置档"
            || value == ssid.trimmed
    }

    var dnsServers: [String] {
        dnsServersText
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == " " || $0 == "\t" })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    var validationMessages: [String] {
        var messages: [String] = []

        if ssid.trimmed.isEmpty {
            messages.append("请填写要匹配的 Wi-Fi 名称。")
        }

        guard mode == .manual else {
            return messages
        }

        if !ipAddress.trimmed.isIPv4Address {
            messages.append("IP 地址格式不正确。")
        }
        if !subnetMask.trimmed.isIPv4Address {
            messages.append("子网掩码格式不正确。")
        }
        if !router.trimmed.isIPv4Address {
            messages.append("路由器地址格式不正确。")
        }

        let invalidDNS = dnsServers.first { !$0.trimmed.isIPv4Address }
        if invalidDNS != nil {
            messages.append("DNS 服务器格式不正确。")
        }

        return messages
    }

    var isReady: Bool {
        validationMessages.isEmpty
    }
}

struct AppSettings: Codable, Equatable, Sendable {
    var autoApply: Bool
    var applyDHCPForUnmatchedNetworks: Bool
    var selectedProfileID: UUID?
    var profiles: [WiFiProfile]

    static let defaults = AppSettings(
        autoApply: false,
        applyDHCPForUnmatchedNetworks: true,
        selectedProfileID: nil,
        profiles: [WiFiProfile.makeDefaultManual()]
    ).normalized()

    func normalized() -> AppSettings {
        var copy = self
        if copy.profiles.isEmpty {
            copy.profiles = [WiFiProfile.makeDefaultManual()]
        }

        if let selectedProfileID = copy.selectedProfileID,
           copy.profiles.contains(where: { $0.id == selectedProfileID }) {
            return copy
        }

        copy.selectedProfileID = copy.profiles.first?.id
        return copy
    }

    func matchingProfile(for ssid: String, preferredProfileID: UUID? = nil) -> WiFiProfile? {
        if let preferredProfileID,
           let preferredProfile = profiles.first(where: { profile in
               profile.id == preferredProfileID
                   && !profile.ssid.trimmed.isEmpty
                   && profile.ssid.trimmed == ssid.trimmed
           }) {
            return preferredProfile
        }

        return profiles.first { profile in
            !profile.ssid.trimmed.isEmpty && profile.ssid.trimmed == ssid.trimmed
        }
    }
}

struct WiFiStatus: Equatable, Sendable {
    var serviceName: String?
    var deviceName: String?
    var currentSSID: String?
    var method: IPConfigurationMethod
    var ipAddress: String?
    var subnetMask: String?
    var router: String?
    var dnsServers: [String]

    static let empty = WiFiStatus(
        serviceName: nil,
        deviceName: nil,
        currentSSID: nil,
        method: .unknown,
        ipAddress: nil,
        subnetMask: nil,
        router: nil,
        dnsServers: []
    )
}

struct WiFiNetworkService: Equatable, Sendable {
    var serviceName: String
    var deviceName: String
}

enum DesiredNetworkConfiguration: Equatable, Sendable {
    case manual(WiFiProfile)
    case dhcp

    var label: String {
        switch self {
        case .manual:
            "手动 IP"
        case .dhcp:
            "DHCP"
        }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isIPv4Address: Bool {
        let parts = split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else {
            return false
        }

        return parts.allSatisfy { part in
            guard !part.isEmpty, part.allSatisfy(\.isNumber), let value = Int(part) else {
                return false
            }
            return (0...255).contains(value)
        }
    }
}
