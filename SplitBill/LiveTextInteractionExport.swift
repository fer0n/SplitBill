//
//  LiveTextInteractionExport.swift
//  SplitBill
//
//  Created by fer0n on 20.08.23.
//

import SwiftUI
import Foundation
import UIKit

extension LiveTextInteraction {
    
    nonisolated func generateExportImage() async throws -> UIImage? {
        guard let image = await imageView.image else {
            throw ExportImageError.noImageFound
        }
        let layer = await imageView.layer
        
        // bottom cards
        let referenceHeight = min(image.size.width, image.size.height) / 35
        let cardsLayer = await getCardsSummaryLayerWithBackground(cards: vm.chosenNormalCards, referenceHeight: referenceHeight)
        let cardsDrawingHeight = cardsLayer.frame.height - 3
        cardsLayer.frame = CGRect(x: 0, y: image.size.height, width: image.size.width, height: cardsLayer.frame.height)
        
        // clear transaction rects && draw
        if let drawingLayer = await drawTransactions(cardIsHighlighted: ({ card in card.isChosen }), hideUnselected: true) {
            layer.sublayers?.removeAll()
            layer.addSublayer(drawingLayer)
            layer.addSublayer(cardsLayer)
        }

        // Create a renderer with the size of the view
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: image.size.width, height: image.size.height + cardsDrawingHeight), format: format)

        // Render the image and the layer into an image
        let imageWithTransactions = renderer.image { ctx in
            layer.render(in: ctx.cgContext)
        }
        
        return imageWithTransactions
    }

    private func getCardsSummaryLayerWithBackground(cards: [Card], referenceHeight: CGFloat) -> CALayer {
        // values
        let padding = referenceHeight
        let seperatorHeight = referenceHeight / 6
        let seperatorColor = UIColor(Color.exportCardSeperator).cgColor
        let backgroundColor = UIColor(Color.exportCardBackground).cgColor
        
        let layer = CALayer()
        
        // cards
        let cardsLayer = getCardsArrangedLayer(cards: cards,
                                               referenceHeight: referenceHeight,
                                               cardPadding: padding / 2,
                                               maxWidth: imageView.frame.width - (padding * 2))
        let cardsX = padding
        let cardsY = padding
        cardsLayer.frame = CGRect(x: cardsX, y: cardsY, width: cardsLayer.frame.width, height: cardsLayer.frame.height)
        
        // background
        let backgroundLayer = CAShapeLayer()
        // workaround: +5 to get rid of green line at the bottom
        let rect = CGRect(x: 0, y: 0, width: imageView.frame.width, height: cardsLayer.frame.height + (padding * 2))
        backgroundLayer.path = UIBezierPath(rect: rect).cgPath
        backgroundLayer.fillColor = backgroundColor

        // seperator color: on top of background
        let seperatorLayer = CAShapeLayer()
        let seperatorRect = CGRect(x: 0, y: 0, width: imageView.frame.width, height: seperatorHeight)
        seperatorLayer.path = UIBezierPath(rect: seperatorRect).cgPath
        seperatorLayer.fillColor = seperatorColor
        
        layer.addSublayer(backgroundLayer)
        layer.addSublayer(seperatorLayer)
        layer.addSublayer(cardsLayer)
        layer.frame = CGRect(x: 0, y: 0, width: imageView.frame.width, height: cardsLayer.frame.height + (padding * 2))
        
        return layer
    }
    
    private func getCardsArrangedLayer(cards: [Card], referenceHeight: CGFloat, cardPadding: CGFloat, maxWidth: CGFloat) -> CALayer {
        let cardsLayer = CALayer()
        var cardsWidth = 0.0
        var currentRow = 0.0
        var cardsInCurrentRow = 0.0
        var currentRowLayer = CALayer()
        var cardLayer = CALayer()
        
        for card in cards {
            cardLayer = getCardAsLayer(card: card, referenceHeight: referenceHeight)
            let cardHeight = cardLayer.frame.height
            let currentWidth = cardLayer.bounds.size.width
            let totalWidth = cardsWidth + (cardPadding * (cardsInCurrentRow > 0 ? cardsInCurrentRow - 1 : 0))
            
            if totalWidth + currentWidth + cardPadding > maxWidth {
                let y = currentRow * (cardHeight + cardPadding)
                let x = (maxWidth - totalWidth) / 2
                currentRowLayer.frame = CGRect(x: x, y: y, width: maxWidth, height: cardHeight)
                cardsLayer.addSublayer(currentRowLayer)
                currentRowLayer = CALayer()
                
                cardsInCurrentRow = 0
                currentRow += 1
                cardsWidth = 0
            }
            
            let x = cardsWidth + (cardPadding * cardsInCurrentRow)
            cardLayer.frame = CGRect(x: x, y: 0, width: currentWidth, height: cardHeight)
            currentRowLayer.addSublayer(cardLayer)
            
            cardsInCurrentRow += 1
            cardsWidth += currentWidth
            
            // NEXT: could the last card be added twice here?
            if cards.last == card {
                let totalWidth = cardsWidth + (cardPadding * (cardsInCurrentRow > 0 ? cardsInCurrentRow - 1 : 0))
                let y = currentRow * (cardHeight + cardPadding)
                let x = (maxWidth - totalWidth) / 2
                currentRowLayer.frame = CGRect(x: x, y: y, width: maxWidth, height: cardHeight)
                cardsLayer.addSublayer(currentRowLayer)
            }
        }
        
        // NEXT: height: one row doesn't have padding, mistake here?
        let cardHeight = cardLayer.frame.height
        cardsLayer.frame = CGRect(x: 0, y: 0, width: maxWidth, height: (currentRow + 1) * cardHeight + (currentRow * cardPadding))
        return cardsLayer
    }
    
    private func getCardAsLayer(card: Card, referenceHeight: CGFloat) -> CALayer {
        let layer = CALayer()
        
        // Constants for font sizes and padding
        let valueFontSize: CGFloat = referenceHeight * 1.5
        let nameFontSize: CGFloat = referenceHeight * 1
        let horizontalPadding: CGFloat = referenceHeight * 1.5
        let verticalPadding: CGFloat = referenceHeight
        
        // value
        let valueFont = UIFont.rounded(ofSize: valueFontSize, weight: .heavy)
        let valueString = vm.sumString(of: card)
        let valueAtt: [NSAttributedString.Key: Any] = [.font: valueFont, .foregroundColor: UIColor.white]
        let valueAttString = NSAttributedString(string: valueString, attributes: valueAtt)
        let valueWidth = valueAttString.boundingRect(with: CGSize(width: .greatestFiniteMagnitude, height: valueFontSize * 2),
                                                    options: .usesLineFragmentOrigin,
                                                    context: nil).width
        // name
        let nameFont = UIFont.rounded(ofSize: nameFontSize, weight: .semibold)
        let nameString = card.name
        let nameAtt: [NSAttributedString.Key: Any] = [.font: nameFont, .foregroundColor: UIColor.white]
        let nameAttString = NSAttributedString(string: nameString, attributes: nameAtt)
        let nameWidth = nameAttString.boundingRect(with: CGSize(width: .greatestFiniteMagnitude, height: nameFontSize * 2),
                                                    options: .usesLineFragmentOrigin,
                                                    context: nil).width
        
        let cardWidth = max(valueWidth, nameWidth) + 2 * horizontalPadding // Add horizontal padding to the card width
        let cardHeight = valueFontSize + nameFontSize + verticalPadding
        
        // Draw rounded rectangle on layer
        let fillColor = UIColor(card.color.dark).cgColor
        let rect = CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
        let sublayer = CAShapeLayer()
        sublayer.contentsScale = UIScreen.main.scale
        let cornerRadius: CGFloat = 1000.0
        let roundRect = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.allCorners],
            cornerRadii: CGSize(width: cornerRadius, height: cornerRadius)
        )
        sublayer.path = roundRect.cgPath
        sublayer.fillColor = fillColor
        layer.addSublayer(sublayer)
        
        // Value
        let valueLayer = CATextLayer()
        valueLayer.string = valueAttString
        valueLayer.alignmentMode = .center
        valueLayer.frame = CGRect(x: 0, y: cardHeight / 2 - valueFontSize, width: cardWidth, height: valueFontSize * 2)
        valueLayer.display()
        layer.addSublayer(valueLayer)
        
        // Name
        let nameLayer = CATextLayer()
        nameLayer.string = nameAttString
        nameLayer.alignmentMode = .center
        nameLayer.frame = CGRect(x: 0, y: cardHeight / 2, width: cardWidth, height: nameFontSize * 2)
        nameLayer.display()
        layer.addSublayer(nameLayer)
        
        // update layer size
        layer.frame = CGRect(x: 0, y: 0, width: cardWidth, height: cardHeight)
        
        return layer
    }
}
