//
//  util.swift
//  SplitBill
//
//  Created by fer0n on 26.11.22.
//

import Foundation
import SwiftUI

func validateNumberFormat(_ str: String) throws -> String? {
    let regexUsNumber = try NSRegularExpression(pattern: "^(- ?)?\\d+(?:,\\d{3})*\\.?\\d*$")
    let matchUsNumber = regexUsNumber.firstMatch(in: str, range: NSRange(str.startIndex..., in: str))
    var matchEuNumber: NSTextCheckingResult?

    if matchUsNumber == nil {
        let regexEuNumber = try NSRegularExpression(pattern: "^(- ?)?\\d+(?:\\.\\d{3})*,?\\d*$")
        matchEuNumber = regexEuNumber.firstMatch(in: str, range: NSRange(str.startIndex..., in: str))

        if matchEuNumber == nil {
            throw NSError(domain: "Invalid number format",
                          code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "Invalid number format \(str)"])
        }
    }

    if matchUsNumber != nil {
        return "."
    } else if matchEuNumber != nil {
        return ","
    } else {
        return nil
    }
}

func findNumberIndices(_ input: String) -> [(range: Range<String.Index>, decimalPoint: String?)] {
    guard let fuzzyRegex = try? NSRegularExpression(pattern: "(?:- ?)?\\d+(?:[,.]\\d{3})*(?:[,.]\\d+)?\\b") else {
        return []
    }
    let potentialNumbers = fuzzyRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
    var matchIndices: [(range: Range<String.Index>, decimalPoint: String?)] = []

    for number in potentialNumbers {
        let match = input[Range(number.range, in: input)!]
        var decimalPoint: String?
        do {
            decimalPoint = try validateNumberFormat(String(match))
        } catch {
            continue
        }
        let range = Range(number.range, in: input)!
        matchIndices.append((range, decimalPoint))
    }

    return matchIndices
}

func cleanNumberString(input: String, decimalPoint: String?) -> Double? {
    var str = input.replacingOccurrences(of: " ", with: "")
    if decimalPoint == "." {
        str = str.replacingOccurrences(of: ",", with: "")
    } else if decimalPoint == "," {
        str = str.replacingOccurrences(of: ".", with: "")
    }
    str = str.replacingOccurrences(of: ",", with: ".")
    return Double.parse(from: str)
}
