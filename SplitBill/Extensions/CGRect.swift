//
//  CGRect.swift
//  SplitBill
//
//  Created by fer0n on 07.09.23.
//

import Foundation

extension CGRect {
    public var cornerRadius: CGFloat {
        0.2 * min(self.width, self.height)
    }
}
