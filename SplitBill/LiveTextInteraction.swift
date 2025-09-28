import UIKit
import SwiftUI
import VisionKit
import Vision
import CoreImage

struct LiveTextInteraction: UIViewRepresentable {
    let imageView = UIImageView()
    @EnvironmentObject var cvm: ContentViewModel
    let invertColors: Bool
    let markerColor: Color

    private static var invertedImageCache = [Int: UIImage]()

    class Coordinator: NSObject, ImageAnalysisInteractionDelegate {
        var parent: LiveTextInteraction

        init(_ parent: LiveTextInteraction) {
            self.parent = parent
            super.init()

            parent.imageView.isUserInteractionEnabled = true
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(imageTapped))
            tapGesture.numberOfTapsRequired = 1
            parent.imageView.addGestureRecognizer(tapGesture)

            let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(imageLongPressed))
            parent.imageView.addGestureRecognizer(longPressGesture)
        }

        @MainActor @objc func imageTapped(_ sender: UITapGestureRecognizer) {
            // do something when image tapped
            let point = sender.location(in: parent.imageView)
            parent.cvm.handleTap(at: point)
        }

        @MainActor @objc func imageLongPressed(_ sender: UILongPressGestureRecognizer) {
            // do something when image tapped
            let point = sender.location(in: parent.imageView)
            if sender.state == .began {
                parent.cvm.handleLongPress(at: point)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UIImageView {
        self.cvm.generateExportImage = self.generateExportImage
        return imageView
    }

    func updateUIView(_ uiView: UIImageView, context: Context) {
        if invertColors, let image = cvm.image {
            uiView.image = invertImage(image)
        } else {
            uiView.image = cvm.image
        }

        if let drawingLayer = drawTransactions() {
            uiView.layer.sublayers?.removeAll()
            uiView.layer.addSublayer(drawingLayer)
        }
    }

    func drawTransactions(cardIsHighlighted: ((Card) -> Bool)? = nil, hideUnselected: Bool = false) -> CALayer? {
        guard let img = cvm.image else { return nil }
        let chosenCards = cvm.chosenCards
        var unusedTransactions = cvm.transactionList
        let layer = CALayer()

        for card in chosenCards {
            let rects: [(rect: CGRect, corners: UIRectCorner?)] = card.transactionIds.compactMap { tId in
                if let index = unusedTransactions.firstIndex(where: { $0.id == tId }) {
                    unusedTransactions.remove(at: index)
                }
                if let transaction = cvm.getTransaction(tId) {
                    if transaction.shares.count > 1 {
                        if let rect = getSharedBoundingBox(transaction, card) {
                            return rect
                        }
                    } else {
                        if let box = transaction.boundingBox {
                            return (rect: box, corners: .allCorners)
                        }
                    }
                }
                return nil
            }
            let cardIsHighlighted = cardIsHighlighted?(card) ?? card.isActive
            let subLayer = drawRectsOnImage(rects, img, color: card.color.light, fill: true, stroke: cardIsHighlighted)
            if cardIsHighlighted {
                layer.insertSublayer(subLayer, at: UInt32((layer.sublayers?.count ?? 1)))
            } else {
                layer.insertSublayer(subLayer, at: 0)
            }
        }
        if hideUnselected {
            return layer
        }
        let unusedRects: [(rect: CGRect, corners: UIRectCorner?)] = unusedTransactions.compactMap { unusedTransaction in
            if let box = unusedTransaction.boundingBox {
                return (rect: box, corners: .allCorners)
            }
            return nil
        }
        let unusedRectsLayer = drawRectsOnImage(unusedRects,
                                                img,
                                                color: markerColor,
                                                fill: false,
                                                stroke: true)
        layer.insertSublayer(unusedRectsLayer, at: 0)
        return layer
    }

    func getSharedBoundingBox(_ transaction: Transaction, _ card: Card) -> (rect: CGRect, corners: UIRectCorner?)? {
        let sorted = cvm.chosenCards.compactMap { card in
            let share = transaction.shares[card.id]
            return share == nil ? nil : (cardId: card.id, share: transaction.shares[card.id])
        }

        guard let box = transaction.boundingBox,
              let shareIndex = sorted.firstIndex(where: { $0.cardId == card.id }) else { return nil }
        let shareCount = CGFloat(transaction.shares.count)
        let width = box.width / shareCount
        let indexValue = sorted.distance(from: 0, to: shareIndex)
        let minX = box.minX + CGFloat(indexValue) * width
        let rect = CGRect(x: minX, y: box.minY, width: width, height: box.height)
        var corners: UIRectCorner? = .allCorners
        if indexValue == 0 {
            // left beginning
            corners = [.bottomLeft, .topLeft]
        } else if CGFloat(indexValue) == shareCount - 1 {
            // right ending
            corners = [.bottomRight, .topRight]
        } else {
            // center
            corners = nil
        }
        return (rect: rect, corners: corners)
    }

    private func drawRectsOnImage(_ rects: [(rect: CGRect, corners: UIRectCorner?)],
                                  _ image: UIImage,
                                  color: Color,
                                  fill: Bool = true,
                                  stroke: Bool = false) -> CALayer {
        let strokeColor = UIColor(color).cgColor
        let fillColor = UIColor(color.opacity(0.5)).cgColor
        let lineWidth = cvm.lineWidth ?? 3.0
        let layer = CALayer()

        for (rect, corners) in rects {
            let sublayer = CAShapeLayer()
            sublayer.contentsScale = UIScreen.main.scale
            let roundRect = UIBezierPath(
                roundedRect: rect,
                byRoundingCorners: corners ?? [],
                cornerRadii: CGSize(width: rect.cornerRadius, height: rect.cornerRadius)
            )
            sublayer.path = roundRect.cgPath
            if fill {
                sublayer.fillColor = fillColor
            } else {
                sublayer.fillColor = UIColor.clear.cgColor
            }

            if stroke {
                sublayer.strokeColor = strokeColor
                sublayer.lineCap = .square
                sublayer.lineWidth = lineWidth
            }

            layer.addSublayer(sublayer)
        }
        return layer
    }

    func invertImage(_ image: UIImage) -> UIImage? {
        let imageIdentifier = image.hashValue
        if let cachedImage = Self.invertedImageCache[imageIdentifier] {
            return cachedImage
        }
        guard let cgImage = image.cgImage else { return nil }

        let ciImage = CIImage(cgImage: cgImage)
        let filter = CIFilter(name: "CIColorInvert")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)

        guard let outputCIImage = filter?.outputImage,
              let outputCGImage = CIContext().createCGImage(outputCIImage, from: outputCIImage.extent) else {
            return nil
        }

        let invertedImage = UIImage(cgImage: outputCGImage, scale: image.scale, orientation: image.imageOrientation)
        Self.invertedImageCache[imageIdentifier] = invertedImage

        return invertedImage
    }
}

enum ExportImageError: Error {
    case noImageFound
    case couldntGetImageData
}
