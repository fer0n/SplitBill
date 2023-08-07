

import UIKit
import SwiftUI
import VisionKit
import Vision


struct LiveTextInteraction: UIViewRepresentable {
    let imageView = UIImageView()
    @ObservedObject var vm: ContentViewModel
    

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
            parent.vm.handleTap(at: point)
        }
        
        
        @MainActor @objc func imageLongPressed(_ sender: UILongPressGestureRecognizer) {
            // do something when image tapped
            let point = sender.location(in: parent.imageView)
            if (sender.state == .began) {
                parent.vm.handleLongPress(at: point)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIImageView {
        return imageView
    }
    
    func updateUIView(_ uiView: UIImageView, context: Context) {
        uiView.image = vm.image
        if let drawingLayer = drawTransactions() {
            uiView.layer.sublayers?.removeAll()
            uiView.layer.addSublayer(drawingLayer)
        }
    }
    
    func drawTransactions() -> CALayer? {
        guard let img = vm.image else { return nil }
        let chosenCards = vm.chosenCards
        var unusedTransactions = vm.transactionList
        let layer = CALayer()
        
        for card in chosenCards {
            let rects: [(rect: CGRect, corners: UIRectCorner?)] = card.transactionIds.compactMap { tId in
                if let index = unusedTransactions.firstIndex(where: { $0.id == tId }) {
                    unusedTransactions.remove(at: index)
                }
                if let t = vm.getTransaction(tId) {
                    if (t.shares.count > 1) {
                        if let r = getSharedBoundingBox(t, card) {
                            return r
                        }
                    } else {
                        if let b = t.boundingBox {
                            return (rect: b, corners: .allCorners)
                        }
                    }
                }
                return nil
            }
            let subLayer = drawRectsOnImage(rects, img, color: card.color.light, fill: true, stroke: card.isActive)
            if (card.isActive) {
                layer.insertSublayer(subLayer, at: UInt32((layer.sublayers?.count ?? 1)))
            } else {
                layer.insertSublayer(subLayer, at: 0)
            }
        }
        
        let unusedRects: [(rect: CGRect, corners: UIRectCorner?)] = unusedTransactions.compactMap { t in
            if let b = t.boundingBox {
                return (rect: b, corners: .allCorners)
            }
            return nil
        }
        let l = drawRectsOnImage(unusedRects, img, color: Color(vm.markerColor ?? .black), fill: false, stroke: true)
        layer.insertSublayer(l, at: 0)
        return layer
    }
    
    func getSharedBoundingBox(_ transaction: Transaction, _ card: Card) -> (rect: CGRect, corners: UIRectCorner?)? {
        let sorted = vm.chosenCards.compactMap { card in
            let share = transaction.shares[card.id]
            return share == nil ? nil : (cardId: card.id, share: transaction.shares[card.id])
        }
        
        guard let b = transaction.boundingBox,
              let shareIndex = sorted.firstIndex(where: { $0.cardId == card.id }) else { return nil }
        let shareCount = CGFloat(transaction.shares.count)
        let width = b.width / shareCount
        let indexValue = sorted.distance(from: 0, to: shareIndex)
        let minX = b.minX + CGFloat(indexValue) * width
        let rect = CGRect(x: minX, y: b.minY, width: width, height: b.height)
        var corners: UIRectCorner? = .allCorners
        if (indexValue == 0) {
            // left beginning
            corners = [.bottomLeft, .topLeft]
        } else if (CGFloat(indexValue) == shareCount - 1) {
            // right ending
            corners = [.bottomRight, .topRight]
        } else {
            // center
            corners = nil
        }
        return (rect: rect, corners: corners)
    }
    
    private func drawRectsOnImage(_ rects: [(rect: CGRect, corners: UIRectCorner?)], _ image: UIImage, color: Color, fill: Bool = true, stroke: Bool = false) -> CALayer {
        let strokeColor = UIColor(color).cgColor
        let fillColor = UIColor(color.opacity(0.5)).cgColor
        
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
            if (fill) {
                sublayer.fillColor = fillColor
            } else {
                sublayer.fillColor = UIColor.clear.cgColor
            }
            
            if (stroke) {
                sublayer.strokeColor = strokeColor
                sublayer.lineCap = .square
                sublayer.lineWidth = 3.0
            }
            
            layer.addSublayer(sublayer)
        }
        return layer
    }
}


extension CGRect {
    var cornerRadius: CGFloat {
        0.2 * min(self.width, self.height)
    }
}


