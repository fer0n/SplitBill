//
//  ShareViewController.swift
//  SplitBill Extension
//
//  Created by fer0n on 21.01.23.
//
//

import UIKit
import MobileCoreServices
import UniformTypeIdentifiers
import SwiftUI
import SplitBillShared

@objc(ShareExtensionViewController)
class ShareViewController: UIViewController {

    @IBOutlet weak var checkmarkIcon: UIImageView!
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    @IBOutlet weak var openInAppLabel: UILabel!
    @IBOutlet weak var imageSavedLabel: UILabel!
    @IBOutlet weak var openInAppButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var selectedImage: UIImageView!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.handleSharedFile()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        spinner.startAnimating()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        openInAppButton.setTitle(NSLocalizedString("openInApp", comment: ""), for: .normal)
        openInAppButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .heavy)
        openInAppButton.backgroundColor = UIColor.white
        openInAppButton.layer.cornerRadius = 15
        openInAppButton.clipsToBounds = true
        spinner.hidesWhenStopped = true

        imageSavedLabel.text = NSLocalizedString("imageSaved", comment: "")
        openInAppLabel.text = NSLocalizedString("openInAppExplanation", comment: "")

        hideSuccessUI()
    }

    @IBAction func handleOpenInAppButton() {
        openSplitBillApp()
    }

    @IBAction func handleCloseButton() {
        cancelExtension()
    }

    private func cancelExtension() {
        // swiftlint:disable:next discouraged_direct_init
        self.extensionContext?.cancelRequest(withError: NSError())
    }

    private func closeExtension() {
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func hideSuccessUI() {
        openInAppButton.isEnabled = false
        imageSavedLabel.isHidden = true
        openInAppLabel.isHidden = true
        checkmarkIcon.isHidden = true
    }

    private func handleSharedFile() {
        hideSuccessUI()

        // extracting the path to the URL that is being shared
        let attachments = (self.extensionContext?.inputItems.first as? NSExtensionItem)?.attachments ?? []
        let contentType = UTType.image.identifier
        let identifier = "public.heic"

        for provider in attachments {
            if provider.hasItemConformingToTypeIdentifier(identifier) {
                provider.loadItem(forTypeIdentifier: identifier, options: nil) { (data, error) in
                    self.storeImage(data, error)
                }
            } else if provider.hasItemConformingToTypeIdentifier(contentType) {
                provider.loadItem(forTypeIdentifier: contentType,
                                  options: nil) { (data, error) in
                    self.storeImage(data, error)
                }

            }
        }

    }

    func storeImage(_ data: NSSecureCoding?, _ error: Error?) {
        guard error == nil else { return }
        if let url = data as? URL,
           let uiImg = UIImage(contentsOfFile: url.path) {
            saveImageData(uiImg)
        } else if let uiImg = data as? UIImage {
            saveImageData(uiImg)
        } else if let data = data as? Data,
                  let uiImg = UIImage(data: data) {
            saveImageData(uiImg)
        } else {
            fatalError("Impossible to save image")
        }
    }

    private func displayError() {
        self.imageSavedLabel.text = NSLocalizedString("error", comment: "")
        self.imageSavedLabel.isHidden = false
        self.openInAppLabel.text = NSLocalizedString("errorMessage", comment: "")
        self.openInAppLabel.isHidden = false
        self.openInAppButton.isEnabled = true
        self.spinner.stopAnimating()
    }

    private func saveImageData(_ image: UIImage) {
        DispatchQueue.main.async {
            var data: Data
            do {
                data = try saveImageDataToSplitBill(image, isPreservation: false)
            } catch {
                self.displayError()
                return
            }

            let targetSize = CGSizeApplyAffineTransform(self.selectedImage.frame.size,
                                                        CGAffineTransform(scaleX: 3, y: 3))
            let image = UIImage(data: data) ?? image
            let lowResImage = resizeImage(image: image, targetSize: targetSize)
            self.selectedImage.image = makeRoundedImage(image: lowResImage)
            self.selectedImage.setNeedsDisplay()

            self.openInAppButton.isEnabled = true
            self.spinner.stopAnimating()
            self.imageSavedLabel.isHidden = false
            self.openInAppLabel.isHidden = false
            self.checkmarkIcon.isHidden = false
        }
    }

    private func openSplitBillApp() {
        guard let url = URL(string: "splitbill://") else {
            closeExtension()
            return
        }
        let close: (Bool) -> Void = { [weak self] _ in self?.closeExtension() }
        // Prefer the host UIApplication (reached via the responder chain); `extensionContext.open`
        // is only reliable for Today widgets, not share extensions opening a custom scheme.
        if hostApplication?.openFromExtension(url, completion: close) == true {
            return
        }
        extensionContext?.open(url, completionHandler: close)
    }

    /// The host process's `UIApplication`, reachable through the responder chain in an extension.
    private var hostApplication: UIApplication? {
        sequence(first: self as UIResponder, next: { $0.next })
            .first { $0 is UIApplication } as? UIApplication
    }
}

private extension UIApplication {
    /// Opens `url` from inside an app extension.
    ///
    /// `open(_:options:completionHandler:)` is unavailable to extensions at compile time, and the
    /// legacy `openURL:` is now hard-blocked by UIKit (force-returns NO), so we invoke the modern
    /// method through the Obj-C runtime. Returns `false` if it isn't available, so the caller can
    /// fall back to `NSExtensionContext.open`.
    @discardableResult
    func openFromExtension(_ url: URL, completion: @escaping (Bool) -> Void) -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        guard responds(to: selector) else { return false }

        typealias OpenURL = @convention(c)
            (NSObject, Selector, NSURL, NSDictionary, @escaping (Bool) -> Void) -> Void
        let open = unsafeBitCast(method(for: selector), to: OpenURL.self)
        open(self, selector, url as NSURL, NSDictionary(), completion)
        return true
    }
}

func makeRoundedImage(image: UIImage) -> UIImage {
    let imageLayer = CALayer()
    let rect = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
    imageLayer.frame = rect
    imageLayer.contents = image.cgImage
    imageLayer.masksToBounds = true
    imageLayer.cornerRadius = rect.cornerRadius

    UIGraphicsBeginImageContext(image.size)
    var roundedImage: UIImage?
    if let context = UIGraphicsGetCurrentContext() {
        imageLayer.render(in: context)
        roundedImage = UIGraphicsGetImageFromCurrentImageContext()
    }
    UIGraphicsEndImageContext()
    return roundedImage ?? image
}

func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
    let size = image.size

    let widthRatio  = targetSize.width  / size.width
    let heightRatio = targetSize.height / size.height

    // Figure out what our orientation is, and use that to form the rectangle
    var newSize: CGSize
    if widthRatio > heightRatio {
        newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
    } else {
        newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
    }

    // This is the rect that we've calculated out and this is what is actually used below
    let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

    // Actually do the resizing to the rect using the ImageContext stuff
    UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
    image.draw(in: rect)
    let newImage = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()

    return newImage!
}

extension CGRect {
    var cornerRadius: CGFloat {
        0.05 * min(self.width, self.height)
    }
}
