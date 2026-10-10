import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct Quote: Identifiable, Codable, Hashable {
    var id = UUID()
    var text: String
    var author: String = ""
    /// File name inside the app's Images folder. When set, the quote is shown as a picture.
    var imageFile: String?

    var isImage: Bool { imageFile != nil }
}

enum RotationInterval: Int, CaseIterable, Identifiable {
    case off = 0
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case hourly = 3600
    case daily = 86400
    var id: Int { rawValue }
    var label: String {
        switch self {
        case .off: "Never"
        case .fiveMinutes: "Every 5 minutes"
        case .fifteenMinutes: "Every 15 minutes"
        case .hourly: "Every hour"
        case .daily: "Every day"
        }
    }
}

/// Holds the user's quotes and appearance settings; persists everything.
@MainActor
final class QuoteStore: ObservableObject {
    @Published var quotes: [Quote] { didSet { saveQuotes(); clampIndex() } }
    @Published var currentIndex: Int { didSet { defaults.set(currentIndex, forKey: "currentIndex") } }
    @Published var isVisible: Bool { didSet { defaults.set(isVisible, forKey: "isVisible") } }

    @Published var rotation: RotationInterval = .hourly { didSet { defaults.set(rotation.rawValue, forKey: "rotation") } }
    @Published var shuffle = false { didSet { defaults.set(shuffle, forKey: "shuffle") } }

    /// Where the quote's center sits, as a fraction of the screen (0...1, top-left origin).
    @Published var anchor = CGPoint(x: 0.5, y: 0.5) {
        didSet { defaults.set(anchor.x, forKey: "anchorX"); defaults.set(anchor.y, forKey: "anchorY") }
    }
    /// While true, the overlay floats above windows and can be dragged and resized.
    @Published var isArranging = false
    @Published var fontSize = 36.0 { didSet { defaults.set(fontSize, forKey: "fontSize") } }
    @Published var serif = true { didSet { defaults.set(serif, forKey: "serif") } }
    @Published var textOpacity = 0.9 { didSet { defaults.set(textOpacity, forKey: "textOpacity") } }
    @Published var darkText = false { didSet { defaults.set(darkText, forKey: "darkText") } }

    private let defaults = UserDefaults.standard
    @Published var imageScale = 0.35 { didSet { defaults.set(imageScale, forKey: "imageScale") } }

    private let fileURL: URL
    private let imagesDir: URL
    private var imageCache: [String: NSImage] = [:]

    init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("QuoteOverlay", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("quotes.json")
        imagesDir = dir.appendingPathComponent("Images", isDirectory: true)
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: fileURL),
           let saved = try? JSONDecoder().decode([Quote].self, from: data) {
            quotes = saved
        } else {
            quotes = [Quote(text: "you should be more ambitious\nway more ambitious", author: "lauren (@poteto)")]
        }

        defaults.register(defaults: ["isVisible": true].merging(Self.settingDefaults) { $1 })
        currentIndex = defaults.integer(forKey: "currentIndex")
        isVisible = defaults.bool(forKey: "isVisible")
        loadSettings()
        clampIndex()
    }

    /// Appearance and rotation settings that "Reset All Settings" restores.
    /// Quotes, pictures, the current quote and Show Quote are not part of this.
    private static let settingDefaults: [String: Any] = [
        "rotation": RotationInterval.hourly.rawValue, "shuffle": false,
        "anchorX": 0.5, "anchorY": 0.5, "fontSize": 36.0, "serif": true,
        "textOpacity": 0.9, "darkText": false, "imageScale": 0.35,
    ]

    func resetSettings() {
        resetSettings(Array(Self.settingDefaults.keys))
    }

    /// Restores just these settings (UserDefaults keys) to their defaults.
    func resetSettings(_ keys: [String]) {
        keys.forEach(defaults.removeObject(forKey:))
        loadSettings()
    }

    func isDefault(_ keys: [String]) -> Bool {
        keys.allSatisfy { key in
            guard let current = defaults.object(forKey: key) as? NSObject else { return true }
            return current.isEqual(Self.settingDefaults[key])
        }
    }

    private func loadSettings() {
        rotation = RotationInterval(rawValue: defaults.integer(forKey: "rotation")) ?? .hourly
        shuffle = defaults.bool(forKey: "shuffle")
        anchor = CGPoint(x: defaults.double(forKey: "anchorX"), y: defaults.double(forKey: "anchorY"))
        fontSize = defaults.double(forKey: "fontSize")
        serif = defaults.bool(forKey: "serif")
        textOpacity = defaults.double(forKey: "textOpacity")
        darkText = defaults.bool(forKey: "darkText")
        imageScale = defaults.double(forKey: "imageScale")
    }

    var currentQuote: Quote? {
        quotes.indices.contains(currentIndex) ? quotes[currentIndex] : nil
    }

    func next() {
        guard quotes.count > 1 else { return }
        if shuffle {
            var i = currentIndex
            while i == currentIndex { i = Int.random(in: 0..<quotes.count) }
            currentIndex = i
        } else {
            currentIndex = (currentIndex + 1) % quotes.count
        }
    }

    func previous() {
        guard quotes.count > 1 else { return }
        currentIndex = (currentIndex - 1 + quotes.count) % quotes.count
    }

    // MARK: Images

    func image(for quote: Quote) -> NSImage? {
        guard let name = quote.imageFile else { return nil }
        if let cached = imageCache[name] { return cached }
        let image = NSImage(contentsOf: imagesDir.appendingPathComponent(name))
        imageCache[name] = image
        return image
    }

    /// Copies an image file into the app's Images folder and attaches it to the quote.
    func setImage(from url: URL, for id: Quote.ID) {
        guard let image = NSImage(contentsOf: url) else { return }
        setImage(image, for: id)
    }

    /// Saves an in-memory image (e.g. pasted from the clipboard) as PNG and attaches it.
    func setImage(_ image: NSImage, for id: Quote.ID) {
        guard let index = quotes.firstIndex(where: { $0.id == id }),
              let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
        else { return }
        let name = UUID().uuidString + ".png"
        guard (try? png.write(to: imagesDir.appendingPathComponent(name))) != nil else { return }
        deleteImageFile(quotes[index].imageFile)
        quotes[index].imageFile = name
    }

    func removeImage(for id: Quote.ID) {
        guard let index = quotes.firstIndex(where: { $0.id == id }) else { return }
        deleteImageFile(quotes[index].imageFile)
        quotes[index].imageFile = nil
    }

    func delete(_ id: Quote.ID) {
        guard let quote = quotes.first(where: { $0.id == id }) else { return }
        deleteImageFile(quote.imageFile)
        quotes.removeAll { $0.id == id }
    }

    private func deleteImageFile(_ name: String?) {
        guard let name else { return }
        imageCache[name] = nil
        try? FileManager.default.removeItem(at: imagesDir.appendingPathComponent(name))
    }

    private func clampIndex() {
        if quotes.isEmpty { currentIndex = 0 } else if currentIndex >= quotes.count || currentIndex < 0 { currentIndex = 0 }
    }

    private func saveQuotes() {
        guard let data = try? JSONEncoder().encode(quotes) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
