import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: QuoteStore

    var body: some View {
        TabView {
            QuotesTab(store: store)
                .tabItem { Label("Quotes", systemImage: "text.quote") }
            AppearanceTab(store: store)
                .tabItem { Label("Appearance", systemImage: "paintbrush") }
        }
        .frame(width: 620, height: 440)
        .padding()
    }
}

private struct QuotesTab: View {
    @ObservedObject var store: QuoteStore
    @State private var selection: Quote.ID?

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 0) {
                List(selection: $selection) {
                    ForEach(store.quotes) { quote in
                        HStack {
                            Image(systemName: "checkmark")
                                .opacity(quote.id == store.currentQuote?.id ? 1 : 0)
                                .foregroundStyle(.secondary)
                            if let image = store.image(for: quote) {
                                Image(nsImage: image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 24)
                                Text(quote.text.isEmpty ? "Picture" : quote.text)
                                    .lineLimit(2)
                            } else {
                                Text(quote.text.isEmpty ? "New quote" : quote.text)
                                    .lineLimit(2)
                            }
                        }
                        .tag(quote.id)
                    }
                    .onMove { store.quotes.move(fromOffsets: $0, toOffset: $1) }
                }
                HStack(spacing: 0) {
                    Button { add() } label: { Image(systemName: "plus").frame(width: 24, height: 20) }
                    Button { remove() } label: { Image(systemName: "minus").frame(width: 24, height: 20) }
                        .disabled(selection == nil)
                    Spacer()
                }
                .buttonStyle(.borderless)
                .padding(4)
            }
            .frame(width: 240)
            .border(Color(nsColor: .separatorColor))

            if let index = store.quotes.firstIndex(where: { $0.id == selection }) {
                let quote = store.quotes[index]
                Form {
                    Section("Picture") {
                        if let image = store.image(for: quote) {
                            Image(nsImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 140)
                        }
                        HStack {
                            Button("Choose Image…") { chooseImage(for: quote.id) }
                            Button("Paste Image") { pasteImage(for: quote.id) }
                            if quote.isImage {
                                Spacer()
                                Button("Use Text Instead", role: .destructive) { store.removeImage(for: quote.id) }
                            }
                        }
                    }
                    if !quote.isImage {
                        Section("Quote") {
                            TextEditor(text: $store.quotes[index].text)
                                .font(.body)
                                .frame(minHeight: 110)
                        }
                        Section("Author (optional)") {
                            TextField("Author", text: $store.quotes[index].author)
                                .labelsHidden()
                        }
                    }
                    Button("Show This Quote Now") { store.currentIndex = index }
                }
                .formStyle(.grouped)
                .onPasteCommand(of: [.image, .fileURL]) { _ in pasteImage(for: quote.id) }
            } else {
                VStack {
                    Spacer()
                    Text("Select a quote to edit, or press + to add one.")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func add() {
        let quote = Quote(text: "")
        store.quotes.append(quote)
        selection = quote.id
    }

    private func remove() {
        guard let id = selection else { return }
        store.delete(id)
        selection = nil
    }

    private func chooseImage(for id: Quote.ID) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            store.setImage(from: url, for: id)
        }
    }

    private func pasteImage(for id: Quote.ID) {
        let pasteboard = NSPasteboard.general
        if let url = (pasteboard.readObjects(forClasses: [NSURL.self],
                                             options: [.urlReadingContentsConformToTypes: [UTType.image.identifier]]) as? [URL])?.first {
            store.setImage(from: url, for: id)
        } else if let image = NSImage(pasteboard: pasteboard) {
            store.setImage(image, for: id)
        } else {
            NSSound.beep()
        }
    }
}

private struct AppearanceTab: View {
    @ObservedObject var store: QuoteStore
    @State private var confirmingReset = false

    var body: some View {
        Form {
            Section("Placement") {
                HStack {
                    Button("Arrange on Screen…") { store.isArranging = true }
                    Button("Reset to Center") { store.anchor = CGPoint(x: 0.5, y: 0.5) }
                }
            }
            Section("Rotation") {
                Picker("Change quote", selection: $store.rotation) {
                    ForEach(RotationInterval.allCases) { Text($0.label).tag($0) }
                }
                Toggle("Shuffle", isOn: $store.shuffle)
            }
            Section("Pictures") {
                LabeledContent("Max size") {
                    Slider(value: $store.imageScale, in: 0.15...0.6) {
                        EmptyView()
                    } minimumValueLabel: { Text("Small") } maximumValueLabel: { Text("Large") }
                }
            }
            Section("Text") {
                LabeledContent("Size") {
                    Slider(value: $store.fontSize, in: 16...96, step: 2)
                }
                LabeledContent("Opacity") {
                    Slider(value: $store.textOpacity, in: 0.2...1)
                }
                Toggle("Serif font", isOn: $store.serif)
                Toggle("Dark text (for light wallpapers)", isOn: $store.darkText)
            }
            Section {
                Button("Reset All Settings…", role: .destructive) { confirmingReset = true }
            } footer: {
                Text("Restores position, size, opacity, font and rotation. Your quotes and pictures are kept.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .confirmationDialog("Reset all settings to their defaults?", isPresented: $confirmingReset) {
            Button("Reset", role: .destructive) { store.resetSettings() }
        } message: {
            Text("Your quotes and pictures won't be touched.")
        }
    }
}
