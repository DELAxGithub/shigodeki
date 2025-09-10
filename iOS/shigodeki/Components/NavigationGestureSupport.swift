import SwiftUI
import UIKit

// Ensures the interactive swipe-back gesture remains enabled
// even when SwiftUI hides the default back button.
private final class _SwipeBackEnablerController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Re-enable the interactive pop gesture and clear any delegate that blocks it
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
}

private struct _SwipeBackEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController { _SwipeBackEnablerController() }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) { }
}

extension View {
    /// Keeps iOS edge-swipe back gesture working with custom back buttons.
    func enableSwipeBack() -> some View {
        background(_SwipeBackEnabler().frame(width: 0, height: 0))
    }
}

