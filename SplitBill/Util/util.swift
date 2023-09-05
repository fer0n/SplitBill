//
//  util.swift
//  SplitBill
//
//  Created by fer0n on 26.11.22.
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


struct DecimalKeyboardWithDone: ViewModifier {
    var onDone: (() -> Void)?
    @FocusState private var isFocused: Bool
    
    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .keyboardType(.decimalPad)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        if let execute = onDone {
                            execute()
                        }
                        isFocused = false
                    } label: {
                        Text("Done")
                            .padding([.vertical], 4)
                            .padding([.horizontal], 15)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .background(Color.markerColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
    }
}


func validateNumberFormat(_ str: String) throws -> String? {
    let regexUsNumber = try NSRegularExpression(pattern: "^(- ?)?\\d+(?:,\\d{3})*\\.?\\d*$")
    let matchUsNumber = regexUsNumber.firstMatch(in: str, range: NSRange(str.startIndex..., in: str))
    var matchEuNumber: NSTextCheckingResult? = nil

    if matchUsNumber == nil {
        let regexEuNumber = try NSRegularExpression(pattern: "^(- ?)?\\d+(?:\\.\\d{3})*,?\\d*$")
        matchEuNumber = regexEuNumber.firstMatch(in: str, range: NSRange(str.startIndex..., in: str))

        if matchEuNumber == nil {
            throw NSError(domain: "Invalid number format", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid number format \(str)"])
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
    let fuzzyRegex = try! NSRegularExpression(pattern: "(?:- ?)?\\d+(?:[,.]\\d{3})*(?:[,.]\\d+)?\\b")
    let potentialNumbers = fuzzyRegex.matches(in: input, range: NSRange(input.startIndex..., in: input))
    var matchIndices: [(range: Range<String.Index>, decimalPoint: String?)] = []

    for number in potentialNumbers {
        let match = input[Range(number.range, in: input)!]
        var decimalPoint: String? = nil
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


extension TextField {
    func decimalKeyboardWithDone(onDone: (() -> Void)? = nil) -> some View {
        modifier(DecimalKeyboardWithDone(onDone: onDone))
    }
}


extension Double {
    static func parse(from string: String) -> Double? {
        let result = Double(string)
        if let r = result, r > Double(Int.max) {
            return nil
        }
        return result
    }
}


extension UIImage {
    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        guard let k = kCFNull else { return nil }
        let context = CIContext(options: [.workingColorSpace: k])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }
}


extension UIColor {
    // Check if the color is light or dark, as defined by the injected lightness threshold.
    // Some people report that 0.7 is best. I suggest to find out for yourself.
    // A nil value is returned if the lightness couldn't be determined.
    func isLight(threshold: Float = 0.5) -> Bool? {
        let originalCGColor = self.cgColor

        // Now we need to convert it to the RGB colorspace. UIColor.white / UIColor.black are greyscale and not RGB.
        // If you don't do this then you will crash when accessing components index 2 below when evaluating greyscale colors.
        let RGBCGColor = originalCGColor.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil)
        guard let components = RGBCGColor?.components else {
            return nil
        }
        guard components.count >= 3 else {
            return nil
        }

        let brightness = Float(((components[0] * 299) + (components[1] * 587) + (components[2] * 114)) / 1000)
        return (brightness > threshold)
    }
}


extension UIFont {
    func calculateHeight(text: String, width: CGFloat) -> CGFloat {
        let constraintRect = CGSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        let boundingBox = text.boundingRect(with: constraintRect,
                                        options: NSStringDrawingOptions.usesLineFragmentOrigin,
                                            attributes: [NSAttributedString.Key.font: self],
                                        context: nil)
        return boundingBox.height
    }
}

extension UIFont {
    class func rounded(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let systemFont = UIFont.systemFont(ofSize: size, weight: weight)
        let font: UIFont
        
        if let descriptor = systemFont.fontDescriptor.withDesign(.rounded) {
            font = UIFont(descriptor: descriptor, size: size)
        } else {
            font = systemFont
        }
        return font
    }
}
