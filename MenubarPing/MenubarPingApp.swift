import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct MenubarPingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var monitor: PingMonitor

    init() {
        let value = PingMonitor()
        _monitor = StateObject(wrappedValue: value)
        value.start()
    }

    var body: some Scene {
        MenuBarExtra {
            SettingsView(monitor: monitor)
        } label: {
            Text(monitor.menuBarTitle.isEmpty ? "MP" : monitor.menuBarTitle)
        }
        .menuBarExtraStyle(.menu)
    }
}
