//
//  Shared.swift
//  SplitBillShared
//
//  Created by fer0n on 03.08.23.
//

import Foundation
import UIKit

public func saveImageDataToSplitBill(_ image: UIImage, isPreservation: Bool?) throws -> Data {
    guard let data = image.jpegData(compressionQuality: 0.6) else {
        throw NSError(domain: "Invalid image data",
                      code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
    }
    try saveImage(data, isPreservation)
    return data
}

public func saveImage(_ data: Data, _ isPreservation: Bool?) throws {
    let encoded = try PropertyListEncoder().encode(data)
    if let userDefaults = UserDefaults(suiteName: "group.splitbill") {
        userDefaults.set(encoded, forKey: "imageData")
        userDefaults.set(isPreservation, forKey: "imageIsPreserved")
    }
}
