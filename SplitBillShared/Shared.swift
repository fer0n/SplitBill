//
//  Shared.swift
//  SplitBillShared
//
//  Created by fer0n on 03.08.23.
//

import Foundation
import UIKit

public func saveImageDataToSplitBill(_ image: UIImage, isHeic: Bool?, isPreservation: Bool?) throws -> Data {
    guard let data = image.jpegData(compressionQuality: 0.6) else {
        throw NSError(domain: "Invalid image data",
                      code: 0,
                      userInfo: [NSLocalizedDescriptionKey: "Invalid image data"])
    }
    try saveImage(data, isHeic, isPreservation)
    return data
}

public func saveImage(_ data: Data, _ isHeic: Bool?, _ isPreservation: Bool?) throws {
    let encoded = try PropertyListEncoder().encode(data)
    if let userDefaults = UserDefaults(suiteName: "group.splitbill") {
        userDefaults.set(encoded, forKey: "imageData")
        userDefaults.set(isHeic, forKey: "isHeic")
        userDefaults.set(isPreservation, forKey: "imageIsPreserved")
    }
}
