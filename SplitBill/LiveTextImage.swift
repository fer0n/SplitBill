//
//  LiveTextImage.swift
//  SplitBill
//

import SwiftUI

struct LiveTextImage: View {
    @EnvironmentObject var cvm: ContentViewModel
    @Environment(\.colorScheme) var colorScheme

    @Binding var showEditCardSheet: Bool
    let zoomBufferPadding: CGFloat

    var body: some View {
        ZoomableScrollView(contentPadding: zoomBufferPadding,
                           ignoreTapsAt: self.ignoreTapsAt,
                           onGestureHasBegun: self.onGestureHasBegun,
                           contentChanged: cvm.contentChanged) {
            ZStack {
                LiveTextInteraction(
                    invertColors: cvm.requiresInvertedColors(colorScheme),
                    markerColor: cvm.getMarkerColor(colorScheme)
                )
                FloatingTransactionView()
            }
            .padding(zoomBufferPadding)
            .overlay(
                Rectangle()
                    .stroke(Color.backgroundColor, lineWidth: 10)
            )
            .background(Color.backgroundColor)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                if cvm.chosenNormalCards.isEmpty {
                    showEditCardSheet = true
                }
            }
        }
    }

    func ignoreTapsAt(_ point: CGPoint) -> Bool {
        return cvm.lastTapWasHitting
    }

    func onGestureHasBegun() {
        cvm.emptyTapTimer?.invalidate()
    }
}
