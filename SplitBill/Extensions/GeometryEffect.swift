//
//  GeometryEffect.swift
//  ScorePad
//
//  Created by rnichi on 06.07.21.
//

import Foundation
import SwiftUI

struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var shakesPerUnit = 3
    var animatableData: CGFloat
    var isActive = true

    func effectValue(size: CGSize) -> ProjectionTransform {
        if (isActive) {
            return ProjectionTransform(CGAffineTransform(translationX:
                                                            amount * sin(animatableData * .pi * CGFloat(shakesPerUnit)),
                                                            y: 0))
        } else {
            return ProjectionTransform()
        }
    }
}
