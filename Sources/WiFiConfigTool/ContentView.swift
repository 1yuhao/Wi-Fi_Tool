import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: WiFiController
    @State private var showsAdvancedSettings = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    currentNetworkPanel
                    homeWiFiPanel
                    automaticSwitchingPanel
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
    private var homeWiFiPanel: some View {
        if let profile = selectedProfileBinding {
            panel("家庭 Wi-Fi", systemImage: "house") {
                VStack(alignment: .leading, spacing: 12) {
                    formRow("名称") {
                        TextField("例如 家庭 Wi-Fi", text: profile.name)
                    }

                    formRow("Wi-Fi 名称") {
                        HStack(spacing: 8) {
                            TextField("家里 Wi-Fi 的名称", text: profile.ssid)

                            Button {
                                controller.useCurrentSSIDForSelectedProfile()
                            } label: {
                                Image(systemName: "target")
                            }
                            .disabled(controller.status.currentSSID == nil)
                            .help("使用当前连接的 Wi-Fi 名称")
                        }
                    }

                    formRow("连接方式") {
                        Picker("连接方式", selection: profile.mode) {
                            Text("手动 IP").tag(WiFiProfileMode.manual)
                            Text("DHCP").tag(WiFiProfileMode.dhcp)
                        }
                        .pickerStyle(.segmented)
                    }

                    if profile.wrappedValue.mode == .manual {
                        manualAddressFields(profile)
                    }

                    validationMessages(for: profile.wrappedValue)
                }
                .textFieldStyle(.roundedBorder)
            }
        } else {
            panel("家庭 Wi-Fi", systemImage: "house") {
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
                Label(primaryApplyTitle, systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .disabled(!controller.canApplySelectedProfile)
            .keyboardShortcut(.return, modifiers: .command)

            Button {
                Task { await controller.applyDHCPConfiguration() }
            } label: {
                Label("恢复 DHCP", systemImage: "network")
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
                profileToolbar
                snapshotActions
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

    private var snapshotActions: some View {
        section("当前配置快照") {
            HStack(spacing: 8) {
                Button {
                    controller.fillSelectedProfileFromCurrentStatus()
                } label: {
                    Label("填入选中档", systemImage: "square.and.arrow.down")
                }
                .disabled(!controller.canUseCurrentNetworkSnapshot || controller.selectedProfile == nil)

                Button {
                    controller.saveCurrentStatusAsProfile()
                } label: {
                    Label("保存为新档", systemImage: "plus.square.on.square")
                }
                .disabled(!controller.canUseCurrentNetworkSnapshot)
            }
            .controlSize(.small)
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

    private var primaryApplyTitle: String {
        guard let profile = controller.selectedProfile else {
            return "应用配置"
        }

        switch profile.mode {
        case .manual:
            return "应用手动 IP"
        case .dhcp:
            return "应用 DHCP"
        }
    }

    private var simpleStatusText: String {
        "当前：\(controller.currentSSIDLabel)"
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
