import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var controller: WiFiController

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            currentStatus
            Divider()
            settingsForm
            Divider()
            actionBar
            messageView
        }
        .padding(16)
        .frame(width: 380)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: controller.menuSystemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text("Wi-Fi Config Tool")
                    .font(.headline)
                Text(controller.currentSSIDLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                Task { await controller.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .disabled(controller.isBusy)
            .help("Refresh")
        }
    }

    private var currentStatus: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
            statusRow("Service", controller.currentServiceLabel)
            statusRow("Mode", controller.currentMethodLabel)
            statusRow("IP", controller.status.ipAddress ?? "-")
            statusRow("Router", controller.status.router ?? "-")
        }
        .font(.callout)
    }

    private func statusRow(_ title: String, _ value: String) -> some View {
        GridRow {
            Text(title)
                .foregroundStyle(.secondary)
            Text(value)
                .lineLimit(1)
                .textSelection(.enabled)
        }
    }

    private var settingsForm: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $controller.settings.autoApply) {
                Label("Auto apply", systemImage: "bolt.horizontal")
            }

            TextField("Home SSID", text: $controller.settings.homeSSID)
            TextField("IP address", text: $controller.settings.ipAddress)
            TextField("Subnet mask", text: $controller.settings.subnetMask)
            TextField("Router", text: $controller.settings.router)
            TextField("DNS servers", text: $controller.settings.dnsServersText)
        }
        .textFieldStyle(.roundedBorder)
    }

    private var actionBar: some View {
        HStack(spacing: 8) {
            Button {
                Task { await controller.applyHomeManualConfiguration() }
            } label: {
                Label("Home Manual", systemImage: "house.and.flag")
            }
            .disabled(!controller.canApplyManual)

            Button {
                Task { await controller.applyDHCPConfiguration() }
            } label: {
                Label("DHCP", systemImage: "network")
            }
            .disabled(!controller.canApplyDHCP)

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit")
        }
    }

    private var messageView: some View {
        HStack(alignment: .top, spacing: 8) {
            if controller.isBusy {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }

            Text(controller.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
