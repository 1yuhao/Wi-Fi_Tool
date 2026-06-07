import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: WiFiController
    @State private var showsAdvancedSettings = false
    @State private var snapshotSSID = ""

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    currentNetworkPanel
                    savedConfigurationPanel
                    advancedSettings
                }
                .padding(16)
            }

            Divider()
            primaryActions
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            Divider()
            feedbackBar
        }
        .frame(width: 520)
        .frame(maxHeight: 700)
        .task {
            syncSnapshotSSIDIfNeeded()
        }
        .onChange(of: controller.status.currentSSID) { _ in
            syncSnapshotSSIDIfNeeded()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: controller.menuSystemImage)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(controller.feedbackKind.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Wi-Fi 配置工具")
                    .font(.headline)
                Text(simpleStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            statusBadge(controller.autoApplyLabel, isActive: controller.settings.autoApply)

            compactIconButton("arrow.clockwise", help: "刷新", disabled: controller.isBusy) {
                Task { await controller.refresh() }
            }
        }
    }

    private var currentNetworkPanel: some View {
        panel("当前网络", systemImage: controller.menuSystemImage) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(controller.currentPolicyTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)

                    Spacer()

                    Text(controller.currentMethodLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                Text(controller.currentPolicySubtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 6) {
                    infoRow("Wi-Fi", controller.currentSSIDLabel)
                    infoRow("IP", controller.status.ipAddress ?? "-")
                    infoRow("路由器", controller.status.router ?? "-")
                    infoRow("DNS", controller.status.dnsServers.joined(separator: ", ").nilIfEmpty ?? "-")
                }
            }
        }
    }

    @ViewBuilder
    private var savedConfigurationPanel: some View {
        if let profile = selectedProfileBinding {
            panel("保存的配置", systemImage: "tray.and.arrow.down") {
                VStack(alignment: .leading, spacing: 12) {
                    formRow("Wi-Fi 名称") {
                        HStack(spacing: 8) {
                            TextField("用于识别这个 Wi-Fi", text: $snapshotSSID)

                            Button {
                                useCurrentSSIDForSnapshot()
                            } label: {
                                Image(systemName: "target")
                            }
                            .disabled(controller.status.currentSSID == nil)
                            .help("使用当前连接的 Wi-Fi 名称")
                        }
                    }

                    HStack(spacing: 8) {
                        Button {
                            controller.saveCurrentStatusAsProfile(ssidOverride: snapshotSSID)
                        } label: {
                            Label("保存为选项", systemImage: "plus.square")
                        }
                        .disabled(!canSnapshotConfiguration)

                        Button {
                            controller.fillSelectedProfileFromCurrentStatus(ssidOverride: snapshotSSID)
                        } label: {
                            Label("覆盖选中项", systemImage: "square.and.arrow.down")
                        }
                        .disabled(!canSnapshotConfiguration || controller.selectedProfile == nil)
                    }
                    .controlSize(.small)

                    Divider()

                    formRow("下次使用") {
                        Picker("选择配置", selection: Binding(
                            get: { controller.settings.selectedProfileID },
                            set: { controller.settings.selectedProfileID = $0 }
                        )) {
                            ForEach(controller.settings.profiles) { profile in
                                Label(profile.displayName, systemImage: profile.mode.systemImage)
                                    .tag(Optional(profile.id))
                            }
                        }
                    }

                    savedProfileSummary(profile.wrappedValue)
                }
                .textFieldStyle(.roundedBorder)
            }
        } else {
            panel("保存的配置", systemImage: "tray.and.arrow.down") {
                Text("暂无配置档。")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var automaticSwitchingPanel: some View {
        panel("自动切换", systemImage: "bolt.horizontal") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $controller.settings.autoApply) {
                    Label("连接匹配的 Wi-Fi 时自动应用配置", systemImage: "bolt.horizontal")
                }

                Toggle(isOn: $controller.settings.applyDHCPForUnmatchedNetworks) {
                    Label("其他 Wi-Fi 自动恢复 DHCP", systemImage: "arrow.triangle.2.circlepath")
                }

                Toggle(isOn: Binding(
                    get: { controller.launchAtLoginEnabled },
                    set: { controller.setLaunchAtLogin($0) }
                )) {
                    Label("开机后自动运行", systemImage: "poweron")
                }

                if controller.launchAtLoginRequiresApproval {
                    Label("需要在系统设置中批准开机自启。", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var primaryActions: some View {
        HStack(spacing: 10) {
            Button {
                Task { await controller.applySelectedProfile() }
            } label: {
                Label("应用选中配置", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!controller.canApplySelectedProfile)
            .keyboardShortcut(.return, modifiers: .command)

            Button {
                Task { await controller.applyDHCPConfiguration() }
            } label: {
                Label("一键恢复 DHCP", systemImage: "network")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!controller.canApplyDHCP)

            compactIconButton("power", help: "退出") {
                NSApplication.shared.terminate(nil)
            }
        }
    }

    private var advancedSettings: some View {
        DisclosureGroup(isExpanded: $showsAdvancedSettings) {
            VStack(alignment: .leading, spacing: 14) {
                automaticSwitchingPanel
                profileToolbar
                selectedProfileEditor
            }
            .padding(.top, 10)
        } label: {
            Label("高级设置", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.14))
        }
    }

    private var profileToolbar: some View {
        section("多个配置档") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Picker("配置档", selection: Binding(
                        get: { controller.settings.selectedProfileID },
                        set: { controller.settings.selectedProfileID = $0 }
                    )) {
                        ForEach(controller.settings.profiles) { profile in
                            Label(profile.displayName, systemImage: profile.mode.systemImage)
                                .tag(Optional(profile.id))
                        }
                    }

                    compactIconButton("plus", help: "新增配置档") {
                        controller.addProfile()
                    }

                    compactIconButton("doc.on.doc", help: "复制配置档", disabled: controller.selectedProfile == nil) {
                        controller.duplicateSelectedProfile()
                    }

                    compactIconButton("trash", help: "删除配置档", disabled: controller.selectedProfile == nil) {
                        controller.deleteSelectedProfile()
                    }
                }

                Button {
                    controller.inspectSelectedProfile()
                } label: {
                    Label("检查配置", systemImage: "checklist")
                }
                .disabled(controller.selectedProfile == nil)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var selectedProfileEditor: some View {
        if let profile = selectedProfileBinding {
            section("详细配置") {
                VStack(alignment: .leading, spacing: 10) {
                    formRow("SSID") {
                        TextField("要匹配的 Wi-Fi 名称", text: profile.ssid)
                    }

                    if profile.wrappedValue.mode == .manual {
                        manualAddressFields(profile)
                    }
                }
                .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func savedProfileSummary(_ profile: WiFiProfile) -> some View {
        VStack(spacing: 6) {
            infoRow("名称", profile.displayName)
            infoRow("Wi-Fi", profile.ssid.trimmed.nilIfEmpty ?? "未设置")
            infoRow("模式", profile.mode.displayName)

            if profile.mode == .manual {
                infoRow("IP", profile.ipAddress.trimmed.nilIfEmpty ?? "-")
                infoRow("路由器", profile.router.trimmed.nilIfEmpty ?? "-")
                infoRow("DNS", profile.dnsServers.joined(separator: ", ").nilIfEmpty ?? "-")
            }
        }
    }

    @ViewBuilder
    private func manualAddressFields(_ profile: Binding<WiFiProfile>) -> some View {
        formRow("IP 地址") {
            TextField("例如 192.168.1.20", text: profile.ipAddress)
        }
        formRow("子网掩码") {
            TextField("例如 255.255.255.0", text: profile.subnetMask)
        }
        formRow("路由器") {
            TextField("例如 192.168.1.1", text: profile.router)
        }
        formRow("DNS") {
            TextField("例如 1.1.1.1, 8.8.8.8", text: profile.dnsServersText)
        }
    }

    @ViewBuilder
    private func validationMessages(for profile: WiFiProfile) -> some View {
        let messages = profile.validationMessages
        if !messages.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(messages, id: \.self) { message in
                    Label(message, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var feedbackBar: some View {
        HStack(alignment: .top, spacing: 8) {
            if controller.isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: controller.feedbackKind.systemImage)
                    .foregroundStyle(controller.feedbackKind.tint)
                    .frame(width: 16)
            }

            Text(controller.message)
                .font(.caption)
                .foregroundStyle(controller.feedbackKind.tint)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 42, alignment: .leading)
    }

    private func panel<Content: View>(_ title: String, systemImage: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))

            content()
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.14))
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func formRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            content()
        }
    }

    private func infoRow(_ title: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .lineLimit(1)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    private func statusBadge(_ text: String, isActive: Bool) -> some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(isActive ? Color.green : Color.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill((isActive ? Color.green : Color.secondary).opacity(0.12))
            }
    }

    private func compactIconButton(_ systemName: String, help: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.borderless)
        .disabled(disabled)
        .help(help)
    }

    private var simpleStatusText: String {
        "当前：\(controller.currentSSIDLabel)"
    }

    private var canSnapshotConfiguration: Bool {
        let hasWiFiName = !snapshotSSID.trimmed.isEmpty || controller.status.currentSSID?.trimmed.nilIfEmpty != nil
        return controller.canUseCurrentNetworkSnapshot && hasWiFiName
    }

    private func useCurrentSSIDForSnapshot() {
        guard let ssid = controller.status.currentSSID?.trimmed, !ssid.isEmpty else {
            return
        }

        snapshotSSID = ssid
    }

    private func syncSnapshotSSIDIfNeeded() {
        guard snapshotSSID.trimmed.isEmpty else {
            return
        }

        useCurrentSSIDForSnapshot()
    }

    private var selectedProfileBinding: Binding<WiFiProfile>? {
        guard let selectedProfileID = controller.settings.selectedProfileID else {
            return nil
        }

        return Binding(
            get: { controller.profile(id: selectedProfileID) ?? WiFiProfile.makeDefaultManual() },
            set: { controller.updateProfile($0) }
        )
    }
}

private extension FeedbackKind {
    var tint: Color {
        switch self {
        case .info:
            .secondary
        case .success:
            .green
        case .warning:
            .orange
        case .error:
            .red
        }
    }

    var systemImage: String {
        switch self {
        case .info:
            "info.circle"
        case .success:
            "checkmark.circle"
        case .warning:
            "exclamationmark.triangle"
        case .error:
            "xmark.octagon"
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
