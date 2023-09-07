import SwiftUI
import Combine

class CenteringScrollView: UIScrollView {
    func centerContent() {
        assert(subviews.count == 1)
        mutate(&subviews[0].frame) {
            // not clear why view.center.{x,y} = bounds.mid{X,Y} doesn't work -- maybe transform?
            $0.origin.x = max(0, bounds.width - $0.width) / 2
            $0.origin.y = max(0, bounds.height - $0.height) / 2
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        centerContent()
    }
}

struct ZoomableScrollView<Content: View>: View {
    let content: Content
    let contentPadding: CGFloat
    let ignoreTapsAt: (CGPoint) -> Bool
    let onGestureHasBegun: () -> Void
    weak var contentChanged: PassthroughSubject<Void, Never>?

    init(contentPadding: CGFloat,
         ignoreTapsAt: @escaping (CGPoint) -> Bool,
         onGestureHasBegun: @escaping () -> Void,
         contentChanged: PassthroughSubject<Void, Never>,
         @ViewBuilder content: () -> Content) {
        self.content = content()
        self.ignoreTapsAt = ignoreTapsAt
        self.contentPadding = contentPadding
        self.contentChanged = contentChanged
        self.onGestureHasBegun = onGestureHasBegun
    }

    var body: some View {
        ZoomableScrollViewImpl(content: content,
                               contentPadding: contentPadding,
                               ignoreTapsAt: self.ignoreTapsAt,
                               onGestureHasBegun: self.onGestureHasBegun,
                               contentChanged: contentChanged?.eraseToAnyPublisher())
    }
}

private struct ZoomableScrollViewImpl<Content: View>: UIViewControllerRepresentable {
    let content: Content
    let contentPadding: CGFloat
    let ignoreTapsAt: (CGPoint) -> Bool
    let onGestureHasBegun: () -> Void
    let contentChanged: AnyPublisher<Void, Never>?

    func makeUIViewController(context: Context) -> ViewController {
        return ViewController(coordinator: context.coordinator,
                              contentPadding: contentPadding,
                              ignoreTapsAt: self.ignoreTapsAt,
                              onGestureHasBegun: self.onGestureHasBegun,
                              contentChanged: contentChanged)
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(hostingController: UIHostingController(rootView: self.content))
    }

    func updateUIViewController(_ viewController: ViewController, context: Context) {
        viewController.update(content: self.content, contentChanged: contentChanged)
    }

    // MARK: - ViewController
    class ViewController: UIViewController, UIScrollViewDelegate {
        let contentPadding: CGFloat
        let coordinator: Coordinator
        private var oldZoomScale: CGFloat?
        let scrollView = CenteringScrollView()
        let onGestureHasBegun: () -> Void

        var requestZoomAndScrollReset: Bool = false
        var contentChangedCancellable: Cancellable?
        var updateConstraintsCancellable: Cancellable?

        private var hostedView: UIView { coordinator.hostingController.view! }

        private var contentSizeConstraints: [NSLayoutConstraint] = [] {
            willSet { NSLayoutConstraint.deactivate(contentSizeConstraints) }
            didSet { NSLayoutConstraint.activate(contentSizeConstraints) }
        }

        required init?(coder: NSCoder) { fatalError() }
        init(coordinator: Coordinator,
             contentPadding: CGFloat,
             ignoreTapsAt: @escaping (CGPoint) -> Bool,
             onGestureHasBegun: @escaping () -> Void,
             contentChanged: AnyPublisher<Void, Never>?) {
            self.coordinator = coordinator
            self.contentPadding = contentPadding
            self.onGestureHasBegun = onGestureHasBegun
            super.init(nibName: nil, bundle: nil)
            self.view = scrollView

            let gesture = OneHandedZoomGestureRecognizer(target: self, action: #selector(handleZoomGesture))
            gesture.ignoreTapsAt = ignoreTapsAt
            scrollView.addGestureRecognizer(gesture)

            scrollView.delegate = self  // for viewForZooming(in:)
            scrollView.maximumZoomScale = 10
            scrollView.minimumZoomScale = 1
            scrollView.bouncesZoom = true
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.clipsToBounds = false
            scrollView.scrollsToTop = false

            let hostedView = coordinator.hostingController.view!
            hostedView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.addSubview(hostedView)
            NSLayoutConstraint.activate([
                hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
            ])

            updateConstraintsCancellable = scrollView.publisher(for: \.bounds).map(\.size).removeDuplicates()
                .sink { [unowned self] _ in
                    view.setNeedsUpdateConstraints()
                }
            contentChangedCancellable = contentChanged?.sink { [unowned self] in handleContentChanged() }
        }

        @objc func handleZoomGesture(_ sender: OneHandedZoomGestureRecognizer) {
            if sender.state == .began {
                self.onGestureHasBegun()
                oldZoomScale = scrollView.zoomScale
            } else if sender.state == .changed {
                guard let oldZoomScale = oldZoomScale else { return }

                let zoomFactor: CGFloat = 0.005
                let zoomChange = sender.yOffset * zoomFactor

                // Calculate the new zoom scale using a logarithmic approach
                // (otherwise zooming while being close feels slow and zooming while being further away feel too fast)
                let logOldZoomScale = log(oldZoomScale)
                let logNewZoomScale = logOldZoomScale - zoomChange
                let newZoomScale = exp(logNewZoomScale)
                scrollView.setZoomScale(newZoomScale, animated: true)
            }
        }

        func handleContentChanged() {
            requestZoomAndScrollReset = true
        }

        func update(content: Content, contentChanged: AnyPublisher<Void, Never>?) {
            coordinator.hostingController.rootView = content
            scrollView.setNeedsUpdateConstraints()
            contentChangedCancellable = contentChanged?.sink { [unowned self] in handleContentChanged() }
        }

        override func updateViewConstraints() {
            super.updateViewConstraints()
            let hostedContentSize = coordinator.hostingController.sizeThatFits(in: view.bounds.size)
            contentSizeConstraints = [
                hostedView.widthAnchor.constraint(equalToConstant: hostedContentSize.width),
                hostedView.heightAnchor.constraint(equalToConstant: hostedContentSize.height)
            ]
        }

        func resetZoom() {
            let padding = self.contentPadding
            let bounds = hostedView.bounds
            let viewRect = CGRect(x: bounds.minX + padding,
                                  y: bounds.minY + padding,
                                  width: bounds.width - (padding * 2),
                                  height: bounds.height - (padding * 2))
            scrollView.zoom(to: viewRect, animated: false)
        }

        override func viewDidAppear(_ animated: Bool) {
            resetZoom()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            let hostedContentSize = coordinator.hostingController.sizeThatFits(in: view.bounds.size)
            scrollView.minimumZoomScale = min(
                scrollView.bounds.width / hostedContentSize.width,
                scrollView.bounds.height / hostedContentSize.height)

            if requestZoomAndScrollReset {
                resetZoom()
                self.scrollView.centerContent()
                requestZoomAndScrollReset = false
            }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            self.scrollView.centerContent()
        }

        override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
            coordinator.animate { [self] _ in
                scrollView.zoom(to: hostedView.bounds, animated: false)
            }
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return hostedView
        }
    }

    // MARK: - Coordinator
    class Coordinator: NSObject, UIScrollViewDelegate {
        var hostingController: UIHostingController<Content>

        init(hostingController: UIHostingController<Content>) {
            self.hostingController = hostingController
        }
    }
}

public func mutate<T>(_ arg: inout T, _ body: (inout T) -> Void) {
    body(&arg)
}
