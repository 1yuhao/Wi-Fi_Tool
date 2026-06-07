import Foundation
import ServiceManagement
import SwiftUI

private struct LegacyWiFiSettings: Codable {
    var homeSSID: String
    var ipAddress: String
    var subnetMask: String
    var router: String
    var dnsServersText: String
    var autoApply: Bool
}

@MainActor
final class WiFiController: ObservableObject {
    @Published var settings: AppSettings {
        didSet {
            guard !isNormalizingSettings else {
                return
            }
            normalizeSettings()
            saveSettings()
            lastAutoAttemptSignature = nil
        }
    }
    @Published private(set) var status = WiFiStatus.empty
    @Published private(set) var isBusy = false
    @Published private(set) var message = "已就绪。"
    @Published private(set) var feedbackKind: FeedbackKind = .info
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginRequiresApproval = false

    private let settingsKey = "WiFiConfigTool.settings.v2"
    private let legacySettingsKey = "WiFiConfigTool.settings.v1"
    private var refreshTimer: Timer?
    private var lastAutoAttemptSignature: String?
    private var isNormalizingSettings = false

    init() {
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let saved = try? JSONDecoder().decode(AppSettings.self, from: data) {
            settings = saved.normalized()
        } else if let data = UserDefaults.standard.data(forKey: legacySettingsKey),
                  let legacy = try? JSONDecoder().decode(LegacyWiFiSettings.self, from: data) {
            settings = AppSettings(
                autoApply: legacy.autoApply,
                applyDHCPForUnmatchedNetworks: true,
                selectedProfileID: nil,
                profiles: [
                    WiFiProfile(
                        id: UUID(),
                        name: "家庭 Wi-Fi",
                        ssid: legacy.homeSSID,
                        mode: .manual,
                        ipAddress: legacy.ipAddress,
                        subnetMask: legacy.subnetMask,
                        router: legacy.router,
                        dnsServersText: legacy.dnsServersText
                    )
                ]
            ).normalized()
        } else {
            settings = .defaults
        }

        saveSettings()
        refreshLaunchAtLoginStatus()

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
        return "Wi-Fi 工具"
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
        status.currentSSID ?? "未连接"
    }

    var currentServiceLabel: String {
        status.serviceName ?? "未知服务"
    }

    var currentMethodLabel: String {
        status.method.displayName
    }

    var selectedProfile: WiFiProfile? {
        if let selectedProfileID = settings.selectedProfileID,
           let selected = settings.profiles.first(where: { $0.id == selectedProfileID }) {
            return selected
        }
        return settings.profiles.first
    }

    var matchedProfileLabel: String {
        guard let ssid = status.currentSSID else {
            return "无"
        }
        return settings.matchingProfile(for: ssid)?.displayName ?? "未匹配"
    }

    var currentPolicyTitle: String {
        guard let ssid = status.currentSSID?.trimmed, !ssid.isEmpty else {
            return "未连接 Wi-Fi"
        }

        if let profile = settings.matchingProfile(for: ssid) {
            return "已匹配：\(profile.displayName)"
        }

        return "未匹配任何配置档"
    }

    var currentPolicySubtitle: String {
        guard status.currentSSID != nil else {
            return "连接 Wi-Fi 后会显示将要应用的策略。"
        }

        if let ssid = status.currentSSID,
           let profile = settings.matchingProfile(for: ssid) {
            return "自动应用时会切换为 \(profile.mode.displayName)。"
        }

        if settings.applyDHCPForUnmatchedNetworks {
            return "自动应用时会恢复 DHCP。"
        }

        return "自动应用时会保持当前网络配置。"
    }

    var autoApplyLabel: String {
        settings.autoApply ? "自动应用已开启" : "自动应用已关闭"
    }

    var canApplySelectedProfile: Bool {
        selectedProfile?.isReady == true && status.serviceName != nil && !isBusy
    }

    var canApplyDHCP: Bool {
        status.serviceName != nil && !isBusy
    }

    var canUseCurrentNetworkSnapshot: Bool {
        status.currentSSID != nil && status.serviceName != nil && !isBusy
    }

    func refresh() async {
        await updateStatus(showSuccessMessage: true)
    }

    func refreshAndAutoApply() async {
        await updateStatus(showSuccessMessage: false)
        await autoApplyIfNeeded()
    }

    func profile(id: UUID) -> WiFiProfile? {
        settings.profiles.first { $0.id == id }
    }

    func updateProfile(_ profile: WiFiProfile) {
        guard let index = settings.profiles.firstIndex(where: { $0.id == profile.id }) else {
            return
        }
        settings.profiles[index] = profile
    }

    func addProfile() {
        let profile = WiFiProfile.makeDefaultDHCP()
        settings.profiles.append(profile)
        settings.selectedProfileID = profile.id
        setMessage("已新增配置档。", kind: .success)
    }

    func duplicateSelectedProfile() {
        guard var profile = selectedProfile else {
            return
        }
        profile.id = UUID()
        profile.name = "\(profile.displayName) 副本"
        settings.profiles.append(profile)
        settings.selectedProfileID = profile.id
        setMessage("已复制配置档。", kind: .success)
    }

    func deleteSelectedProfile() {
        guard let selectedProfileID = settings.selectedProfileID else {
            return
        }

        if settings.profiles.count == 1 {
            settings.profiles = [WiFiProfile.makeDefaultManual()]
            settings.selectedProfileID = settings.profiles.first?.id
            setMessage("已重置最后一个配置档。", kind: .success)
            return
        }

        settings.profiles.removeAll { $0.id == selectedProfileID }
        settings.selectedProfileID = settings.profiles.first?.id
        setMessage("已删除配置档。", kind: .success)
    }

    func useCurrentSSIDForSelectedProfile() {
        guard let ssid = status.currentSSID?.trimmed, !ssid.isEmpty, var profile = selectedProfile else {
            setMessage("当前没有可用的 Wi-Fi 名称。", kind: .warning)
            return
        }

        profile.ssid = ssid
        if profile.name.trimmed.isEmpty || profile.name == "新配置档" {
            profile.name = ssid
        }
        updateProfile(profile)
        setMessage("已填入当前 Wi-Fi 名称。", kind: .success)
    }

    func fillSelectedProfileFromCurrentStatus() {
        guard var profile = selectedProfile else {
            setMessage("请先选择一个配置档。", kind: .warning)
            return
        }

        guard let updatedProfile = currentStatusProfile(id: profile.id, fallbackName: profile.displayName) else {
            setMessage("当前没有可读取的 Wi-Fi 配置。", kind: .warning)
            return
        }

        profile.name = updatedProfile.name
        profile.ssid = updatedProfile.ssid
        profile.mode = updatedProfile.mode
        profile.ipAddress = updatedProfile.ipAddress
        profile.subnetMask = updatedProfile.subnetMask
        profile.router = updatedProfile.router
        profile.dnsServersText = updatedProfile.dnsServersText
        updateProfile(profile)
        setMessage("已把当前网络配置填入选中配置档。", kind: .success)
    }

    func saveCurrentStatusAsProfile() {
        guard let profile = currentStatusProfile(id: UUID(), fallbackName: nil) else {
            setMessage("当前没有可保存的 Wi-Fi 配置。", kind: .warning)
            return
        }

        settings.profiles.append(profile)
        settings.selectedProfileID = profile.id
        setMessage("已保存当前网络为新配置档。", kind: .success)
    }

    func inspectSelectedProfile() {
        guard let profile = selectedProfile else {
            setMessage("请先选择一个配置档。", kind: .warning)
            return
        }

        let validationMessages = profile.validationMessages
        guard validationMessages.isEmpty else {
            setMessage(validationMessages.first ?? "配置档还没有填写完整。", kind: .warning)
            return
        }

        guard let ssid = status.currentSSID?.trimmed, !ssid.isEmpty else {
            setMessage("配置有效；连接到 \(profile.ssid.trimmed) 时会应用 \(profile.mode.displayName)。", kind: .success)
            return
        }

        guard ssid == profile.ssid.trimmed else {
            setMessage("配置有效；当前 Wi-Fi 是 \(ssid)，不会匹配此配置档。", kind: .warning)
            return
        }

        let desired: DesiredNetworkConfiguration = profile.mode == .manual ? .manual(profile) : .dhcp
        if isSatisfied(desired, by: status) {
            setMessage("检查通过：当前网络已经符合 \(profile.displayName)。", kind: .success)
        } else {
            setMessage("检查通过：当前 Wi-Fi 会应用 \(profile.mode.displayName)。", kind: .success)
        }
    }

    func applySelectedProfile() async {
        guard let serviceName = status.serviceName else {
            setMessage("未找到 Wi-Fi 网络服务。", kind: .error)
            return
        }

        guard let profile = selectedProfile else {
            setMessage("请先选择一个配置档。", kind: .warning)
            return
        }

        guard profile.isReady else {
            setMessage(profile.validationMessages.first ?? "配置档还没有填写完整。", kind: .warning)
            return
        }

        let desired: DesiredNetworkConfiguration = profile.mode == .manual ? .manual(profile) : .dhcp
        await apply(desired, serviceName: serviceName, isAutomatic: false)
    }

    func applyDHCPConfiguration() async {
        guard let serviceName = status.serviceName else {
            setMessage("未找到 Wi-Fi 网络服务。", kind: .error)
            return
        }

        await apply(.dhcp, serviceName: serviceName, isAutomatic: false)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
                setMessage("已开启开机自动启动。", kind: .success)
            } else {
                try SMAppService.mainApp.unregister()
                setMessage("已关闭开机自动启动。", kind: .success)
            }
            refreshLaunchAtLoginStatus()
        } catch {
            refreshLaunchAtLoginStatus()
            setMessage("开机自启设置失败：\(error.localizedDescription)", kind: .error)
        }
    }

    func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled
        launchAtLoginRequiresApproval = status == .requiresApproval
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
                setMessage("已刷新 \(Date.now.formatted(date: .omitted, time: .shortened))。", kind: .success)
            }
        } catch {
            setMessage(error.localizedDescription, kind: .error)
        }
    }

    private func autoApplyIfNeeded() async {
        guard settings.autoApply else {
            return
        }

        guard let ssid = status.currentSSID?.trimmed, !ssid.isEmpty, let serviceName = status.serviceName else {
            return
        }

        let desired: DesiredNetworkConfiguration
        if let profile = settings.matchingProfile(for: ssid), profile.isReady {
            desired = profile.mode == .manual ? .manual(profile) : .dhcp
        } else if settings.applyDHCPForUnmatchedNetworks {
            desired = .dhcp
        } else {
            return
        }

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
        setMessage("\(isAutomatic ? "自动应用" : "正在应用") \(desired.label)...", kind: .info)

        do {
            try await NetworkSetup.apply(desired, serviceName: serviceName)
            isBusy = false
            await updateStatus(showSuccessMessage: false)
            setMessage("已应用 \(desired.label)。", kind: .success)
        } catch {
            isBusy = false
            setMessage(error.localizedDescription, kind: .error)
        }
    }

    private func currentStatusProfile(id: UUID, fallbackName: String?) -> WiFiProfile? {
        guard let ssid = status.currentSSID?.trimmed, !ssid.isEmpty else {
            return nil
        }

        let mode: WiFiProfileMode = status.method == .dhcp ? .dhcp : .manual
        let name = fallbackName?.trimmed.nilIfEmpty ?? ssid

        return WiFiProfile(
            id: id,
            name: name,
            ssid: ssid,
            mode: mode,
            ipAddress: status.ipAddress ?? "",
            subnetMask: status.subnetMask ?? "",
            router: status.router ?? "",
            dnsServersText: status.dnsServers.joined(separator: ", ")
        )
    }

    private func isSatisfied(_ desired: DesiredNetworkConfiguration, by status: WiFiStatus) -> Bool {
        switch desired {
        case .dhcp:
            return status.method == .dhcp
        case let .manual(profile):
            return status.method == .manual
                && status.ipAddress == profile.ipAddress.trimmed
                && status.subnetMask == profile.subnetMask.trimmed
                && status.router == profile.router.trimmed
                && Set(status.dnsServers) == Set(profile.dnsServers)
        }
    }

    private func autoAttemptSignature(ssid: String, desired: DesiredNetworkConfiguration) -> String {
        switch desired {
        case .dhcp:
            return "\(ssid)|dhcp"
        case let .manual(profile):
            return [
                ssid,
                profile.id.uuidString,
                "manual",
                profile.ipAddress.trimmed,
                profile.subnetMask.trimmed,
                profile.router.trimmed,
                profile.dnsServers.joined(separator: ",")
            ].joined(separator: "|")
        }
    }

    private func normalizeSettings() {
        let normalized = settings.normalized()
        guard normalized != settings else {
            return
        }

        isNormalizingSettings = true
        settings = normalized
        isNormalizingSettings = false
    }

    private func saveSettings() {
        guard let data = try? JSONEncoder().encode(settings.normalized()) else {
            return
        }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }

    private func setMessage(_ value: String, kind: FeedbackKind) {
        message = value
        feedbackKind = kind
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
