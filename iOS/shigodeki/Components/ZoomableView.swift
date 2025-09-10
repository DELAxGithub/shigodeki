import SwiftUI

/// A view that wraps its content in a zoomable and pannable container.
struct ZoomableView<Content: View>: View {
    @ViewBuilder var content: Content
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Limits
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topTrailing) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(
                        SimultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let delta = value / lastScale
                                    lastScale = value
                                    let proposed = scale * delta
                                    scale = min(max(proposed, minScale), maxScale)
                                }
                                .onEnded { _ in
                                    lastScale = 1.0
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        if scale < minScale { scale = minScale }
                                        if scale > maxScale { scale = maxScale }
                                        if scale == minScale { offset = .zero; lastOffset = .zero }
                                    }
                                },
                            DragGesture()
                                .onChanged { value in
                                    // Only allow dragging when zoomed in
                                    if scale > 1.0 {
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                }
                                .onEnded { _ in lastOffset = offset }
                        )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            if scale > 1.01 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }

                if scale > 1.01 {
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            scale = 1.0
                            offset = .zero
                            lastOffset = .zero
                        }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(8)
                            .background(.thinMaterial)
                            .clipShape(Capsule())
                            .accessibilityLabel("ズームをリセット")
                    }
                    .padding(12)
                }
            }
        }
    }
}
