import Foundation
import SwiftUI

@MainActor
final class WiFiController: ObservableObject {
    @Published var settings: WiFiSettings {
        didSet {
            saveSettings()
            lastAutoAttemptSignature = nil
        }
    }
    @Published private(set) var status = WiFiStatus.empty
    @Published private(set) var isBusy = false
    @Published private(set) var message = "Ready."

    private let defaultsKey = "WiFiConfigTool.settings.v1"
    private var refreshTimer: Timer?
    private var lastAutoAttemptSignature: String?

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode(WiFiSettings.self, from: data) {
            settings = saved
        } else {
            settings = .defaults
        }

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refreshAndAutoApply()
            }
        }

        Task {
            await refreshAndAutoApply()
        }
    }

    var menuTitle: String {
        if let ssid = status.currentSSID, !ssid.isEmpty {
            return ssid
        }
        return "Wi-Fi Tool"
    }

    var menuSystemImage: String {
        guard status.currentSSID != nil else {
            return "wifi.slash"
        }

        switch status.method {
        case .dhcp:
            return "wifi"
        case .manual:
            return "wifi.router"
        case .unknown:
            return "wifi.exclamationmark"
        }
    }

    var currentSSIDLabel: String {
        status.currentSSID ?? "Not connected"
    }

    var currentServiceLabel: String {
        status.serviceName ?? "Unknown service"
    }

    var currentMethodLabel: String {
        status.method.rawValue
    }

    var canApplyManual: Bool {
        settings.isReadyForManualConfiguration && status.serviceName != nil && !isBusy
    }

    var canApplyDHCP: Bool {
        status.serviceName != nil && !isBusy
    }

    func refresh() async {
        await updateStatus(showSuccessMessage: true)
    }

    func refreshAndAutoApply() async {
        await updateStatus(showSuccessMessage: false)
        await autoApplyIfNeeded()
    }

    func applyHomeManualConfiguration() async {
        guard let serviceName = status.serviceName else {
            message = "Wi-Fi service not found."
            return
        }

        guard settings.isReadyForManualConfiguration else {
            message = "Fill in Home SSID, IP address, subnet mask, and router first."
            return
        }

        await apply(.manual(settings), serviceName: serviceName, isAutomatic: false)
    }

    func applyDHCPConfiguration() async {
        guard let serviceName = status.serviceName else {
            message = "Wi-Fi service not found."
            return
        }

        await apply(.dhcp, serviceName: serviceName, isAutomatic: false)
    }

    private func updateStatus(showSuccessMessage: Bool) async {
        guard !isBusy else {
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            status = try await NetworkSetup.currentStatus()
            if showSuccessMessage {
                message = "Updated \(Date.now.formatted(date: .omitted, time: .shortened))."
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func autoApplyIfNeeded() async {
        guard settings.autoApply, settings.isReadyForManualConfiguration else {
            return
        }

        guard let ssid = status.currentSSID?.trimmed, !ssid.isEmpty, let serviceName = status.serviceName else {
            return
        }

        let desired: DesiredNetworkConfiguration = ssid == settings.homeSSID.trimmed ? .manual(settings) : .dhcp
        guard !isSatisfied(desired, by: status) else {
            return
        }

        let signature = autoAttemptSignature(ssid: ssid, desired: desired)
        guard signature != lastAutoAttemptSignature else {
            return
        }

        lastAutoAttemptSignature = signature
        await apply(desired, serviceName: serviceName, isAutomatic: true)
    }

    private func apply(_ desired: DesiredNetworkConfiguration, serviceName: String, isAutomatic: Bool) async {
        guard !isBusy else {
            return
        }

        isBusy = true
        message = "\(isAutomatic ? "Auto applying" : "Applying") \(desired.label)..."

        do {
            try await NetworkSetup.apply(desired, serviceName: serviceName)
            isBusy = false
            await updateStatus(showSuccessMessage: false)
            message = "\(desired.label) applied."
        } catch {
            isBusy = false
            message = error.localizedDescription
        }
    }

    private func isSatisfied(_ desired: DesiredNetworkConfiguration, by status: WiFiStatus) -> Bool {
        switch desired {
        case .dhcp:
            return status.method == .dhcp
        case let .manual(settings):
            return status.method == .manual
                && status.ipAddress == settings.ipAddress.trimmed
                && status.subnetMask == settings.subnetMask.trimmed
                && status.router == settings.router.trimmed
                && Set(status.dnsServers) == Set(settings.dnsServers)
        }
    }

    private func autoAttemptSignature(ssid: String, desired: DesiredNetworkConfiguration) -> String {
        switch desired {
        case .dhcp:
            return "\(ssid)|dhcp"
        case let .manual(settings):
            return [
                ssid,
                "manual",
                settings.ipAddress.trimmed,
                settings.subnetMask.trimmed,
                settings.router.trimmed,
                settings.dnsServers.joined(separator: ",")
            ].joined(separator: "|")
        }
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
