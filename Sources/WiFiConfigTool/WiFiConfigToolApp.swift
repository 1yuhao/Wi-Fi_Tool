import SwiftUI

@main
struct WiFiConfigToolApp: App {
    @StateObject private var controller = WiFiController()

    var body: some Scene {
        MenuBarExtra("Wi-Fi 工具", systemImage: controller.menuSystemImage) {
            ContentView()
                .environmentObject(controller)
        }
        .menuBarExtraStyle(.window)
    }
}
