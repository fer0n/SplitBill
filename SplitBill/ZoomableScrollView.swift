

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
    weak var contentChanged: PassthroughSubject<Void, Never>?
    
    init(contentPadding: CGFloat, ignoreTapsAt: @escaping (CGPoint) -> Bool, contentChanged: PassthroughSubject<Void, Never>, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.ignoreTapsAt = ignoreTapsAt
        self.contentPadding = contentPadding
        self.contentChanged = contentChanged
    }
        
    var body: some View {
        ZoomableScrollViewImpl(content: content, contentPadding: contentPadding, ignoreTapsAt: self.ignoreTapsAt, contentChanged: contentChanged?.eraseToAnyPublisher())
    }
}



fileprivate struct ZoomableScrollViewImpl<Content: View>: UIViewControllerRepresentable {
  let content: Content
  let contentPadding: CGFloat
  let ignoreTapsAt: (CGPoint) -> Bool
  let contentChanged: AnyPublisher<Void, Never>?

    
  func makeUIViewController(context: Context) -> ViewController {
      return ViewController(coordinator: context.coordinator, contentPadding: contentPadding, ignoreTapsAt: self.ignoreTapsAt, contentChanged: contentChanged)
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

    var requestZoomAndScrollReset: Bool = false
    var contentChangedCancellable: Cancellable?
    var updateConstraintsCancellable: Cancellable?

    private var hostedView: UIView { coordinator.hostingController.view! }

    private var contentSizeConstraints: [NSLayoutConstraint] = [] {
      willSet { NSLayoutConstraint.deactivate(contentSizeConstraints) }
      didSet { NSLayoutConstraint.activate(contentSizeConstraints) }
    }

    required init?(coder: NSCoder) { fatalError() }
      init(coordinator: Coordinator, contentPadding: CGFloat, ignoreTapsAt: @escaping (CGPoint) -> Bool, contentChanged: AnyPublisher<Void, Never>?) {
      self.coordinator = coordinator
      self.contentPadding = contentPadding
      super.init(nibName: nil, bundle: nil)
      self.view = scrollView
        
      let ge = OneHandedZoomGestureRecognizer(target: self, action: #selector(handleZoomGesture))
      ge.ignoreTapsAt = ignoreTapsAt
      scrollView.addGestureRecognizer(ge)

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
        hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      ])

      updateConstraintsCancellable = scrollView.publisher(for: \.bounds).map(\.size).removeDuplicates()
        .sink { [unowned self] size in
          view.setNeedsUpdateConstraints()
        }
      contentChangedCancellable = contentChanged?.sink { [unowned self] in handleContentChanged() }
    }
      
      @objc func handleZoomGesture(_ sender: OneHandedZoomGestureRecognizer) {
          if (sender.state == .began) {
              oldZoomScale = scrollView.zoomScale
          } else if (sender.state == .changed) {
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
        hostedView.heightAnchor.constraint(equalToConstant: hostedContentSize.height),
      ]
    }
      
      func resetZoom() {
          let padding = self.contentPadding
          let i = hostedView.bounds
          let viewRect = CGRect(x: i.minX + padding,
                                y: i.minY + padding,
                                width: i.width - (padding * 2),
                                height: i.height - (padding * 2))
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
        
        if (requestZoomAndScrollReset) {
            resetZoom()
            self.scrollView.centerContent()
            requestZoomAndScrollReset = false
        }
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
      // For some reason this is needed in both didZoom and layoutSubviews, thanks to https://medium.com/@ssamadgh/designing-apps-with-scroll-views-part-i-8a7a44a5adf7
      // Sometimes this seems to work (view animates size and position simultaneously from current position to center) and sometimes it does not (position snaps to center immediately, size change animates)
      self.scrollView.centerContent()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animate { [self] context in
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
