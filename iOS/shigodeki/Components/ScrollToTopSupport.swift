import SwiftUI
import UIKit

// Marks the nearest UIScrollView (or UITableView) so a status bar tap scrolls to top.
// SwiftUI does not expose this directly; we bridge via a zero-sized UIView.
private final class _ScrollsToTopMarkerView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        configure()
    }
    override func layoutSubviews() {
        super.layoutSubviews()
        // Re-assert the flag on layout changes (e.g., navigation transitions)
        configure()
    }
    private func configure() {
        guard let scroll = findNearestScrollView() else { return }
        // Disable scrollsToTop on sibling scroll views to avoid conflicts
        if let container = scroll.superview {
            disableScrollsToTopRecursively(in: container, except: scroll)
        }
        scroll.scrollsToTop = true
    }
    private func findNearestScrollView() -> UIScrollView? {
        var v: UIView? = self
        while let cur = v {
            if let scroll = cur as? UIScrollView { return scroll }
            v = cur.superview
        }
        return nil
    }
    private func disableScrollsToTopRecursively(in root: UIView, except target: UIScrollView) {
        for sub in root.subviews {
            if let s = sub as? UIScrollView, s !== target { s.scrollsToTop = false }
            disableScrollsToTopRecursively(in: sub, except: target)
        }
    }
}

private struct _ScrollsToTopConfigurator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView { _ScrollsToTopMarkerView(frame: .zero) }
    func updateUIView(_ uiView: UIView, context: Context) { }
}

extension View {
    /// Enables iOS's standard behavior: tapping the status bar scrolls to top.
    /// Apply this to the List/ScrollView that should respond.
    func statusBarTapScrollToTop() -> some View {
        background(_ScrollsToTopConfigurator().frame(width: 0, height: 0))
    }
}

