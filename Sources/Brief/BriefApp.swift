import AppKit
import Combine
import Sparkle
import SwiftUI

@main
struct BriefApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // The menu bar item is managed by the delegate, so the app needs no window.
    var body: some Scene {
        Settings {}
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = CalendarModel.shared
    private let updater = Updater.shared
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        popover.behavior = .transient

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        model.$menuBarTitle.combineLatest(model.$menuBarDay)
            .receive(on: RunLoop.main)
            .sink { [weak self] title, day in
                MainActor.assumeIsolated { self?.updateStatusItem(title: title, day: day) }
            }
            .store(in: &cancellables)

        model.start()

        // Screenshot helpers: `open Brief.app --args --popover` / `--settings`
        // opens the popover right away so it can be captured from a script.
        let arguments = CommandLine.arguments
        if arguments.contains("--popover") || arguments.contains("--settings") {
            if arguments.contains("--settings") { model.settingsRequested = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.togglePopover()
            }
        }
    }

    // MARK: - Clicks

    private func updateStatusItem(title: String, day: Int?) {
        guard let button = statusItem?.button else { return }
        button.image = day.map(MenuBarIcon.image(day:))
        button.title = title.isEmpty ? "" : " \(title)"
    }

    @objc private func statusItemClicked() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || event?.modifierFlags.contains(.control) == true
        if isSecondary {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        // Come up on today with fresh events every time the popover opens.
        model.showToday()
        model.reload()
        let hosting = NSHostingController(rootView: PopoverView(model: model))
        // Let SwiftUI's ideal size drive the popover; otherwise NSPopover
        // keeps a stale, larger contentSize and pads the window with dead space.
        hosting.sizingOptions = .preferredContentSize
        popover.contentViewController = hosting
        popover.contentSize = hosting.view.fittingSize
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    /// Attaching the menu makes the status item show it on the next click, so the
    /// left-click action stays intact once it is detached again.
    private func showContextMenu() {
        guard let statusItem, let button = statusItem.button else { return }
        popover.performClose(nil)
        statusItem.menu = contextMenu()
        button.performClick(nil)
        statusItem.menu = nil
    }

    private func contextMenu() -> NSMenu {
        let menu = NSMenu()
        if let upcoming = model.upcoming, upcoming.start <= Date() {
            let title = MenuBarLabel.truncate(upcoming.displayTitle, limit: 30)
            menu.addItem(item(title: "Mark “\(title)” as Over", action: #selector(dismissCurrentMeeting), key: ""))
            menu.addItem(.separator())
        }
        menu.addItem(item(title: "Settings…", action: #selector(openSettings), key: ","))
        let updates = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(SPUStandardUpdaterController.checkForUpdates(_:)),
            keyEquivalent: ""
        )
        updates.target = updater.controller
        menu.addItem(updates)
        menu.addItem(item(title: "Open Calendar", action: #selector(openCalendar), key: ""))
        menu.addItem(.separator())
        menu.addItem(item(title: "Quit Brief", action: #selector(quit), key: "q"))
        return menu
    }

    private func item(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    // MARK: - Menu actions

    @objc private func openSettings() {
        model.settingsRequested = true
        if !popover.isShown { togglePopover() }
    }

    @objc private func dismissCurrentMeeting() { model.dismissCurrentMeeting() }

    @objc private func openCalendar() { model.openCalendarApp() }

    @objc private func quit() { model.quit() }
}
