//
//  Double.swift
//  SplitBill
//
//  Created by fer0n on 03.09.23.
//


import Foundation

extension Double {
    
    /**
     Returns value as string, truncating "1.0" to "1". Several decimal places are truncated to two: "1.124125" -> "1.12"
     */
    var clean: String {
       return self.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", self) : String(format: "%.02f", self)
    }
}


