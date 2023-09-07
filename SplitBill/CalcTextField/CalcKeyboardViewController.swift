//
//  CalcKeyboardViewController.swift
//  ScorePad
//
//  Created by fer0n on 13.07.21.
//

import Foundation
import SwiftUI

class CalcKeyboardViewController: UIViewController, KeyboardDelegate {

    let generator = UIImpactFeedbackGenerator(style: .light)
    let notificationGenerator = UINotificationFeedbackGenerator()

    var textField: UITextField?
    var onSubmit: ((Double?) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()

        generator.prepare()
    }

    // required method for keyboard delegate protocol
    func keyWasTapped(action: KeyboardAction, character: String) {
        guard let textField = textField else { return }

        switch action {
        case .insertNumber:
            textField.insertText(character)
        case .delete:
            textField.deleteBackward()
        case .submit:
            self.notificationGenerator.prepare()
            self.evaluateExpression()
        case .point:
            textField.insertText(".")
        case .insertOperand:
            textField.insertText(character)
        }
    }

    func evaluateExpression() {
        guard let textField = textField,
              let text = textField.text,
              let callback = self.onSubmit else { return }
        if text.isEmpty {
            self.generator.impactOccurred()
            callback(0)
            textField.endEditing(true)
            return
        }
        // check if expression is just a number
        if let res = Double(text) {
            self.generator.impactOccurred()
            callback(res)
            textField.endEditing(true)
        } else {

            // if not evaluate the expression
            var numericExpression = text
            numericExpression = numericExpression.replacingOccurrences(of: "÷", with: "/")
            numericExpression = numericExpression.replacingOccurrences(of: "×", with: "*")

            do {
                try ObjC.catchException {
                    // calls that might throw an NSException
                    var expression = NSExpression(format: numericExpression)
                    expression = expression.toFloatingPointDivision()
                    if let result = expression.expressionValue(with: nil, context: nil) as? Double {

                        // set result
                        callback(result)
                        textField.endEditing(true)
                        textField.text = result.clean
                        // set focus
                        self.generator.impactOccurred()
                    } else {
                        print("failed")
                    }
                }
            } catch {
                print("Calc expression \(numericExpression) can't be resolved: \(error)")
                self.notificationGenerator.notificationOccurred(.error)
                withAnimation(Animation.default) {
                    callback(nil)
                }
            }
        }
    }
}
