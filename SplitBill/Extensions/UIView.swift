//
//  UIView.swift
//  SplitBill
//
//  Created by fer0n on 03.09.23.
//

import Foundation
import UIKit


extension UIView {
    var allSubviews: [UIView] {
        return self.subviews.flatMap { [$0] + $0.allSubviews }
    }
}
