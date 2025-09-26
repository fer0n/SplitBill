//
//  BlurTop.swift
//  SplitBill
//

import SwiftUI

struct BlurTop: View {
    var body: some View {
        GeometryReader { geo in
            if geo.safeAreaInsets.top > 0 {
                Color.clear
                    .background(.thickMaterial)
                    .mask {
                        LinearGradient(gradient: Gradient(colors: [.black, .clear]),
                                       startPoint: .top,
                                       endPoint: .bottom)
                    }
                    .frame(height: geo.safeAreaInsets.top + 25)
                    .edgesIgnoringSafeArea(.top)
            }
        }
    }
}
