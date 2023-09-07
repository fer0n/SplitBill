//
//  PresentationDetent.swift
//  SplitBill
//
//  Created by fer0n on 07.09.23.
//

import Foundation
import SwiftUI

private struct BarDetent: CustomPresentationDetent {
    static func height(in context: Context) -> CGFloat? {
        max(44, context.maxDetentValue * 0.1)
    }
}

extension PresentationDetent {
    static let small = Self.height(200)
}
