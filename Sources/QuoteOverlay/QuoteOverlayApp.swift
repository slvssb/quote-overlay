import AppKit
import ServiceManagement
import SwiftUI

@main
struct QuoteOverlayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Quote Overlay", systemImage: "quote.bubble") {
            MenuContent(store: appDelegate.store)
        }
        Window("Quote Overlay Settings", id: "settings") {
            SettingsView(store: appDelegate.store)
        }
        .windowResizability(.contentSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = QuoteStore()
    private var overlay: OverlayController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        overlay = OverlayController(store: store)
        enableLaunchAtLoginOnFirstInstall()
    }

    /// The first time the installed copy runs, turn on Launch at Login so it survives a restart.
    /// Dev builds (run from the project folder) are left alone. The menu toggle can turn it off.
    private func enableLaunchAtLoginOnFirstInstall() {
        let key = "didAutoEnableLaunchAtLogin"
        let path = Bundle.main.bundlePath
        let installed = path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/")
        guard installed, !UserDefaults.standard.bool(forKey: key) else { return }
        do {
            try SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            NSLog("Couldn't enable launch at login: \(error)")
        }
    }
}

private struct MenuContent: View {
    @ObservedObject var store: QuoteStore
    @Environment(\.openWindow) private var openWindow
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Button("Next Quote") { store.next() }
            .keyboardShortcut("n")
            .disabled(store.quotes.count < 2)
        Button("Previous Quote") { store.previous() }
            .disabled(store.quotes.count < 2)
        Toggle("Show Quote", isOn: $store.isVisible)
        Button(store.isArranging ? "Done Arranging" : "Arrange on Screen…") {
            store.isArranging.toggle()
        }
        .keyboardShortcut("a")
        Divider()
        Button("Settings…") {
            openWindow(id: "settings")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin },
            set: { on in
                do {
                    if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                } catch {
                    NSLog("Launch at login failed: \(error)")
                }
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        ))
        Divider()
        Button("Quit Quote Overlay") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
