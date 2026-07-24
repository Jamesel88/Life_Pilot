import SwiftUI

/// A UIScrollView that keeps its hosted content centred whenever that
/// content is smaller than the visible viewport (a small graph, or any
/// graph once zoomed out) — recentring in `layoutSubviews()` guarantees
/// it happens after every layout pass, unlike calling it from a handful
/// of guessed moments (setup, zoom) which can race the view's real
/// bounds still settling.
private final class CenteringScrollView: UIScrollView {
    weak var hostedContentView: UIView?

    override func layoutSubviews() {
        super.layoutSubviews()
        centerContent()
    }

    func centerContent() {
        guard let contentView = hostedContentView else { return }
        let boundsSize = bounds.size
        var frame = contentView.frame

        frame.origin.x = frame.width < boundsSize.width
            ? (boundsSize.width - frame.width) / 2 : 0
        frame.origin.y = frame.height < boundsSize.height
            ? (boundsSize.height - frame.height) / 2 : 0

        if frame != contentView.frame {
            contentView.frame = frame
        }
    }
}

/// A native pan + pinch-zoom canvas — wraps UIScrollView rather than
/// composing SwiftUI drag/magnification gestures by hand, since
/// UIScrollView already gets the interplay right (rubber-banding,
/// momentum, zoom-anchored-at-pinch-centre) for free.
struct PannableZoomableView<Content: View>: UIViewRepresentable {
    var contentSize: CGSize
    var minZoom: CGFloat = 0.4
    var maxZoom: CGFloat = 2.5
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = CenteringScrollView()
        scrollView.minimumZoomScale = minZoom
        scrollView.maximumZoomScale = maxZoom
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = context.coordinator

        let hosting = UIHostingController(rootView: content())
        hosting.view.backgroundColor = .clear
        hosting.safeAreaRegions = []
        hosting.view.frame = CGRect(origin: .zero, size: contentSize)
        scrollView.addSubview(hosting.view)
        scrollView.contentSize = contentSize
        scrollView.hostedContentView = hosting.view
        context.coordinator.hostingController = hosting

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController?.rootView = content()
        if scrollView.contentSize != contentSize {
            scrollView.contentSize = contentSize
            context.coordinator.hostingController?.view.frame = CGRect(origin: .zero, size: contentSize)
            (scrollView as? CenteringScrollView)?.centerContent()
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            hostingController?.view
        }
    }
}
