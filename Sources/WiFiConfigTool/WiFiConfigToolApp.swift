import SwiftUI

@main
struct WiFiConfigToolApp: App {
    @StateObject private var controller = WiFiController()

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environmentObject(controller)
        } label: {
            Label(controller.menuTitle, systemImage: controller.menuSystemImage)
        }
        .menuBarExtraStyle(.window)
    }
}
