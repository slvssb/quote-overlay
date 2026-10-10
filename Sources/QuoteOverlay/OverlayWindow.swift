import AppKit

/// A click-through, transparent window that sits just above the wallpaper.
///
/// - Level is one above the desktop (wallpaper) window, so it's below desktop
///   icons and every normal app window.
/// - `.transient` makes Mission Control / Exposé hide it, instead of showing it
///   as a window thumbnail or keeping it on screen (`.stationary` would do that).
/// - `.canJoinAllSpaces` keeps it on every desktop Space.
final class OverlayWindow: NSWindow {
    static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) + 1)

    /// Arrange mode: float above other windows and accept mouse input.
    var isArranging = false {
        didSet {
            level = isArranging ? .floating : Self.desktopLevel
            ignoresMouseEvents = !isArranging
        }
    }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        level = Self.desktopLevel
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        animationBehavior = .none
        setFrame(screen.frame, display: false)
    }

    override var canBecomeKey: Bool { isArranging }
    override var canBecomeMain: Bool { false }
}
