import Foundation

enum IPConfigurationMethod: String, Sendable {
    case dhcp = "DHCP"
    case manual = "Manual"
    case unknown = "Unknown"
}

struct WiFiSettings: Codable, Equatable, Sendable {
    var homeSSID: String
    var ipAddress: String
    var subnetMask: String
    var router: String
    var dnsServersText: String
    var autoApply: Bool

    static let defaults = WiFiSettings(
        homeSSID: "",
        ipAddress: "192.168.1.20",
        subnetMask: "255.255.255.0",
        router: "192.168.1.1",
        dnsServersText: "1.1.1.1, 8.8.8.8",
        autoApply: false
    )

    var dnsServers: [String] {
        dnsServersText
            .split(whereSeparator: { $0 == "," || $0 == "\n" || $0 == " " || $0 == "\t" })
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    var isReadyForManualConfiguration: Bool {
        !homeSSID.trimmed.isEmpty
            && !ipAddress.trimmed.isEmpty
            && !subnetMask.trimmed.isEmpty
            && !router.trimmed.isEmpty
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
    case manual(WiFiSettings)
    case dhcp

    var label: String {
        switch self {
        case .manual:
            "Manual"
        case .dhcp:
            "DHCP"
        }
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
