import AppKit
import Combine
import SwiftUI

/// Keeps one overlay window per screen and drives quote rotation.
@MainActor
final class OverlayController {
    private let store: QuoteStore
    private var windows: [OverlayWindow] = []
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var escapeMonitor: Any?

    init(store: QuoteStore) {
        self.store = store
        rebuildWindows()

        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.rebuildWindows() }
            .store(in: &cancellables)

        store.$rotation
            .removeDuplicates()
            .sink { [weak self] interval in self?.restartTimer(interval) }
            .store(in: &cancellables)

        store.$isArranging
            .removeDuplicates()
            .sink { [weak self] arranging in self?.setArranging(arranging) }
            .store(in: &cancellables)
    }

    private func setArranging(_ arranging: Bool) {
        windows.forEach { $0.isArranging = arranging }
        if arranging {
            NSApp.activate(ignoringOtherApps: true)
            (windows.first { $0.screen == NSScreen.main } ?? windows.first)?.makeKeyAndOrderFront(nil)
            escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard event.keyCode == 53 || event.keyCode == 36 else { return event } // Esc / Return
                self?.store.isArranging = false
                return nil
            }
        } else if let monitor = escapeMonitor {
            NSEvent.removeMonitor(monitor)
            escapeMonitor = nil
        }
    }

    private func rebuildWindows() {
        windows.forEach { $0.orderOut(nil) }
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            window.isArranging = store.isArranging
            window.contentView = NSHostingView(rootView: QuoteView(store: store))
            window.orderFront(nil)
            return window
        }
    }

    private func restartTimer(_ interval: RotationInterval) {
        timer?.invalidate()
        timer = nil
        guard interval != .off else { return }
        timer = Timer.scheduledTimer(withTimeInterval: TimeInterval(interval.rawValue), repeats: true) { [weak self] _ in
            Task { @MainActor in self?.store.next() }
        }
    }
}
