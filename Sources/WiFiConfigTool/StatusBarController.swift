import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let controller: WiFiController
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()

    init(controller: WiFiController) {
        self.controller = controller
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()

        super.init()

        configurePopover()
        configureStatusButton()
        observeController()
        updateStatusButton()
    }

    private func configurePopover() {
        popover.animates = true
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 500, height: 680)
        popover.contentViewController = NSHostingController(
            rootView: ContentView()
                .environmentObject(controller)
        )
    }

    private func configureStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.imagePosition = .imageLeading
    }

    private func observeController() {
        controller.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateStatusButton()
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else {
            return
        }

        let image = NSImage(
            systemSymbolName: controller.menuSystemImage,
            accessibilityDescription: controller.menuTitle
        ) ?? NSImage(
            systemSymbolName: "wifi",
            accessibilityDescription: "Wi-Fi 工具"
        )

        image?.isTemplate = true
        button.image = image
        button.title = " WiFi"
        button.toolTip = controller.menuTitle
        button.setAccessibilityLabel(controller.menuTitle)
    }

    @objc
    private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        guard let button = statusItem.button else {
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
