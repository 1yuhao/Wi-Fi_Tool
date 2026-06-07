import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: WiFiController

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    statusSummary
                    automationSettings
                    profileToolbar
                    selectedProfileEditor
                    snapshotActions
                    primaryActions
                }
                .padding(16)
            }

            Divider()
            feedbackBar
        }
        .frame(width: 500)
        .frame(maxHeight: 680)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: controller.menuSystemImage)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(controller.feedbackKind.tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Wi-Fi 配置工具")
                    .font(.headline)
                Text(controller.currentSSIDLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            compactIconButton("arrow.clockwise", help: "刷新", disabled: controller.isBusy) {
                Task { await controller.refresh() }
            }
        }
    }

    private var statusSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(controller.currentPolicyTitle)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(controller.currentPolicySubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                statusBadge(controller.autoApplyLabel, isActive: controller.settings.autoApply)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                summaryRow("服务", controller.currentServiceLabel, "模式", controller.currentMethodLabel)
                summaryRow("IP", controller.status.ipAddress ?? "-", "路由器", controller.status.router ?? "-")
                summaryRow("DNS", controller.status.dnsServers.joined(separator: ", ").nilIfEmpty ?? "-", "匹配", controller.matchedProfileLabel)
            }
            .font(.callout)
        }
    }

    private func summaryRow(_ firstTitle: String, _ firstValue: String, _ secondTitle: String, _ secondValue: String) -> some View {
        GridRow {
            summaryCell(firstTitle, firstValue)
            summaryCell(secondTitle, secondValue)
        }
    }

    private func summaryCell(_ title: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .leading)
            Text(value)
                .lineLimit(1)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var automationSettings: some View {
        section("自动化") {
            VStack(alignment: .leading, spacing: 10) {
                Toggle(isOn: $controller.settings.autoApply) {
                    Label("自动应用匹配配置", systemImage: "bolt.horizontal")
                }

                Toggle(isOn: $controller.settings.applyDHCPForUnmatchedNetworks) {
                    Label("未匹配 Wi-Fi 使用 DHCP", systemImage: "arrow.triangle.2.circlepath")
                }

                Toggle(isOn: Binding(
                    get: { controller.launchAtLoginEnabled },
                    set: { controller.setLaunchAtLogin($0) }
                )) {
                    Label("开机自动启动", systemImage: "poweron")
                }

                if controller.launchAtLoginRequiresApproval {
                    Label("需要在系统设置中批准开机自启。", systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var profileToolbar: some View {
        section("配置档") {
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

                HStack(spacing: 8) {
                    Button {
                        controller.useCurrentSSIDForSelectedProfile()
                    } label: {
                        Label("使用当前 Wi-Fi 名称", systemImage: "target")
                    }
                    .disabled(controller.status.currentSSID == nil || controller.selectedProfile == nil)

                    Button {
                        controller.inspectSelectedProfile()
                    } label: {
                        Label("检查配置", systemImage: "checklist")
                    }
                    .disabled(controller.selectedProfile == nil)
                }
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder
    private var selectedProfileEditor: some View {
        if let profile = selectedProfileBinding {
            VStack(alignment: .leading, spacing: 16) {
                section("匹配条件") {
                    VStack(alignment: .leading, spacing: 10) {
                        formRow("名称") {
                            TextField("例如 家庭 Wi-Fi", text: profile.name)
                        }
                        formRow("SSID") {
                            TextField("要匹配的 Wi-Fi 名称", text: profile.ssid)
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                }

                section("连接策略") {
                    VStack(alignment: .leading, spacing: 10) {
                        formRow("策略") {
                            Picker("连接策略", selection: profile.mode) {
                                ForEach(WiFiProfileMode.allCases) { mode in
                                    Text(mode.displayName).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        if profile.wrappedValue.mode == .manual {
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

                        validationMessages(for: profile.wrappedValue)
                    }
                    .textFieldStyle(.roundedBorder)
                }
            }
        } else {
            Text("暂无配置档。")
                .foregroundStyle(.secondary)
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

    private var primaryActions: some View {
        HStack(spacing: 8) {
            Button {
                Task { await controller.applySelectedProfile() }
            } label: {
                Label("应用配置", systemImage: "checkmark.circle")
            }
            .disabled(!controller.canApplySelectedProfile)
            .keyboardShortcut(.return, modifiers: .command)

            Button {
                Task { await controller.applyDHCPConfiguration() }
            } label: {
                Label("恢复 DHCP", systemImage: "network")
            }
            .disabled(!controller.canApplyDHCP)

            Spacer()

            compactIconButton("power", help: "退出") {
                NSApplication.shared.terminate(nil)
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
                .frame(width: 76, alignment: .leading)
            content()
        }
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
