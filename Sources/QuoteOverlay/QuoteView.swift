import SwiftUI

struct QuoteView: View {
    @ObservedObject var store: QuoteStore
    @State private var dragOffset: CGSize = .zero
    @State private var resizeFactor: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if store.isArranging {
                    Color.black.opacity(0.25)
                        .overlay(alignment: .top) { arrangeHint.padding(.top, 60) }
                }
                if store.isVisible || store.isArranging, let quote = store.currentQuote {
                    item(quote, in: geo.size)
                        .position(
                            x: store.anchor.x * geo.size.width + dragOffset.width,
                            y: store.anchor.y * geo.size.height + dragOffset.height
                        )
                        .id(quote.id)
                        .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .animation(.easeInOut(duration: 0.6), value: store.currentQuote?.id)
        }
    }

    // MARK: Placement

    @ViewBuilder
    private func item(_ quote: Quote, in size: CGSize) -> some View {
        let base = Group {
            if let image = store.image(for: quote) {
                picture(image, in: size)
            } else {
                content(quote)
                    .frame(maxWidth: min(size.width * 0.7, 1100))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if store.isArranging {
            base
                .padding(12)
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                }
                .overlay(alignment: .bottomTrailing) { resizeHandle(quote, in: size) }
                .contentShape(Rectangle())
                .gesture(moveGesture(in: size))
                .onHover { inside in
                    if inside { NSCursor.openHand.push() } else { NSCursor.pop() }
                }
        } else {
            base
        }
    }

    private func moveGesture(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { dragOffset = $0.translation }
            .onEnded { value in
                let x = store.anchor.x + value.translation.width / size.width
                let y = store.anchor.y + value.translation.height / size.height
                store.anchor = CGPoint(x: min(max(x, 0.02), 0.98), y: min(max(y, 0.02), 0.98))
                dragOffset = .zero
            }
    }

    /// Dragging the corner scales the text size or the picture's max size.
    private func resizeHandle(_ quote: Quote, in size: CGSize) -> some View {
        Circle()
            .fill(Color.white)
            .frame(width: 18, height: 18)
            .shadow(radius: 3)
            .offset(x: 9, y: 9)
            .onHover { inside in
                if inside { NSCursor.crosshair.push() } else { NSCursor.pop() }
            }
            .highPriorityGesture(
                DragGesture()
                    .onChanged { value in
                        resizeFactor = max(0.3, 1 + (value.translation.width + value.translation.height) / 400)
                    }
                    .onEnded { _ in
                        if quote.isImage {
                            store.imageScale = min(max(store.imageScale * resizeFactor, 0.1), 0.9)
                        } else {
                            store.fontSize = min(max(store.fontSize * resizeFactor, 14), 160)
                        }
                        resizeFactor = 1
                    }
            )
    }

    private var arrangeHint: some View {
        HStack(spacing: 12) {
            Text("Drag the quote to move it · drag the corner dot to resize")
            Button("Done") { store.isArranging = false }
                .keyboardShortcut(.defaultAction)
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }

    // MARK: Rendering

    /// Fits the picture inside a box that's a fraction of the screen, never full-screen.
    private func picture(_ image: NSImage, in size: CGSize) -> some View {
        let scale = store.imageScale * resizeFactor
        return Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(maxWidth: size.width * scale, maxHeight: size.height * scale)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)
            .opacity(store.textOpacity)
    }

    private func content(_ quote: Quote) -> some View {
        let color: Color = store.darkText ? .black : .white
        let shadow: Color = store.darkText ? .white.opacity(0.5) : .black.opacity(0.55)
        let design: Font.Design = store.serif ? .serif : .default
        let fontSize = store.fontSize * resizeFactor
        return VStack(spacing: fontSize * 0.5) {
            Text(quote.text)
                .font(.system(size: fontSize, weight: .medium, design: design))
                .multilineTextAlignment(.center)
            if !quote.author.trimmingCharacters(in: .whitespaces).isEmpty {
                Text("— \(quote.author)")
                    .font(.system(size: fontSize * 0.5, weight: .regular, design: design))
                    .italic()
            }
        }
        .foregroundStyle(color.opacity(store.textOpacity))
        .shadow(color: shadow, radius: 8, x: 0, y: 2)
        .padding(.horizontal, 40)
    }
}
