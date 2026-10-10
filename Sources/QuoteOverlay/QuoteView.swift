import SwiftUI

struct QuoteView: View {
    @ObservedObject var store: QuoteStore

    // Live drag state. Committed to the store only when the gesture ends.
    @State private var dragOffset: CGSize = .zero
    @State private var resizeFactor: CGFloat = 1
    @State private var isMoving = false
    @State private var snapX = false
    @State private var snapY = false
    @State private var hoverCursorPushed = false

    /// Gestures measure in this fixed, screen-sized space. Measuring in the quote's own
    /// (moving) space is what made dragging shake: every move shifted the reference frame.
    private static let space = "overlay"
    private static let snapDistance: CGFloat = 12

    static let fontSizeRange: ClosedRange<Double> = 14...160
    static let imageScaleRange: ClosedRange<Double> = 0.1...0.9

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if store.isArranging {
                    Color.black.opacity(0.25)
                        .overlay(alignment: .top) { arrangeHint.padding(.top, 60) }
                    guides(in: geo.size)
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
            .coordinateSpace(name: Self.space)
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
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(isMoving ? 0.12 : 0.06))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                }
                .overlay(alignment: .bottomTrailing) { resizeHandle(quote, in: size) }
                .contentShape(Rectangle())
                .gesture(moveGesture(in: size))
                .onHover { setHoverCursor($0 ? .openHand : nil) }
        } else {
            base
        }
    }

    private func moveGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
            .onChanged { value in
                if !isMoving {
                    isMoving = true
                    setHoverCursor(.closedHand)
                }
                var offset = value.translation
                let origin = CGPoint(x: store.anchor.x * size.width, y: store.anchor.y * size.height)

                // Snap to the screen's center lines.
                snapX = abs(origin.x + offset.width - size.width / 2) < Self.snapDistance
                snapY = abs(origin.y + offset.height - size.height / 2) < Self.snapDistance
                if snapX { offset.width = size.width / 2 - origin.x }
                if snapY { offset.height = size.height / 2 - origin.y }
                dragOffset = offset
            }
            .onEnded { _ in
                let x = store.anchor.x + dragOffset.width / size.width
                let y = store.anchor.y + dragOffset.height / size.height
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    store.anchor = CGPoint(x: min(max(x, 0.02), 0.98), y: min(max(y, 0.02), 0.98))
                    dragOffset = .zero
                }
                isMoving = false
                snapX = false
                snapY = false
                setHoverCursor(.openHand)
            }
    }

    /// The corner handle follows the pointer: the new size is the ratio of the pointer's
    /// distance from the quote's center now vs. when the drag started.
    private func resizeHandle(_ quote: Quote, in size: CGSize) -> some View {
        Circle()
            .fill(Color.white)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.2), lineWidth: 1))
            .frame(width: 18, height: 18)
            .padding(8) // larger hit area
            .contentShape(Circle())
            .shadow(radius: 3)
            .offset(x: 17, y: 17)
            .onHover { setHoverCursor($0 ? .crosshair : .openHand) }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let center = CGPoint(x: store.anchor.x * size.width, y: store.anchor.y * size.height)
                        let start = hypot(value.startLocation.x - center.x, value.startLocation.y - center.y)
                        let now = hypot(value.location.x - center.x, value.location.y - center.y)
                        resizeFactor = now / max(start, 1)
                    }
                    .onEnded { _ in
                        if quote.isImage {
                            store.imageScale = imageScale
                        } else {
                            store.fontSize = fontSize
                        }
                        resizeFactor = 1
                    }
            )
    }

    /// Center lines that light up while the quote is snapped to them.
    private func guides(in size: CGSize) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.yellow)
                .frame(width: 1, height: size.height)
                .position(x: size.width / 2, y: size.height / 2)
                .opacity(snapX ? 0.9 : 0)
            Rectangle()
                .fill(Color.yellow)
                .frame(width: size.width, height: 1)
                .position(x: size.width / 2, y: size.height / 2)
                .opacity(snapY ? 0.9 : 0)
        }
        .allowsHitTesting(false)
    }

    private var arrangeHint: some View {
        HStack(spacing: 12) {
            Text("Drag to move · drag the corner dot to resize · snaps to center")
            Button("Done") { store.isArranging = false }
                .keyboardShortcut(.defaultAction)
        }
        .font(.system(size: 14, weight: .medium))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }

    /// Keeps NSCursor's push/pop stack balanced: at most one cursor pushed by this view.
    private func setHoverCursor(_ cursor: NSCursor?) {
        if hoverCursorPushed {
            NSCursor.pop()
            hoverCursorPushed = false
        }
        if let cursor {
            cursor.push()
            hoverCursorPushed = true
        }
    }

    // MARK: Rendering

    private var fontSize: Double {
        min(max(store.fontSize * resizeFactor, Self.fontSizeRange.lowerBound), Self.fontSizeRange.upperBound)
    }

    private var imageScale: Double {
        min(max(store.imageScale * resizeFactor, Self.imageScaleRange.lowerBound), Self.imageScaleRange.upperBound)
    }

    /// Fits the picture inside a box that's a fraction of the screen, never full-screen.
    private func picture(_ image: NSImage, in size: CGSize) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(maxWidth: size.width * imageScale, maxHeight: size.height * imageScale)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 6)
            .opacity(store.textOpacity)
    }

    private func content(_ quote: Quote) -> some View {
        let color: Color = store.darkText ? .black : .white
        let shadow: Color = store.darkText ? .white.opacity(0.5) : .black.opacity(0.55)
        let design: Font.Design = store.serif ? .serif : .default
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
