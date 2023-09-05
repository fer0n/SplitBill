//
//  CalcKeyboardViewController.swift
//  ScorePad
//
//  Created by fer0n on 13.07.21.
//

import Foundation
import SwiftUI

class VC_CalcKeyboard: UIViewController, KeyboardDelegate {

    let generator = UIImpactFeedbackGenerator(style: .light)
    let notificationGenerator = UINotificationFeedbackGenerator()
    
    var textField: UITextField? = nil
    var onSubmit: ((Double?) -> ())? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()

        generator.prepare()
    }

    // required method for keyboard delegate protocol
    func keyWasTapped(action: KeyboardAction, character: String) {
        guard let tf = textField else { return }
        
        switch action {
        case .insertNumber:
            tf.insertText(character)
        case .delete:
            tf.deleteBackward()
        case .submit:
            self.notificationGenerator.prepare()
            self.evaluateExpression()
        case .point:
            tf.insertText(".")
        case .insertOperand:
            tf.insertText(character)
        }
    }
    

    func evaluateExpression() {
        guard let tf = textField,
              let text = tf.text,
              let callback = self.onSubmit else { return }
        if (text.isEmpty) {
            self.generator.impactOccurred()
            callback(0)
            tf.endEditing(true)
            return
        }
        // check if expression is just a number
        if let res = Double(text) {
            self.generator.impactOccurred()
            callback(res)
            tf.endEditing(true)
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
                        tf.endEditing(true)
                        tf.text = result.clean
                        // set focus
                        self.generator.impactOccurred()
                    } else {
                        print("failed")
                    }
                }
            }
            catch {
                print("Calc expression \(numericExpression) can't be resolved: \(error)")
                self.notificationGenerator.notificationOccurred(.error)
                withAnimation(Animation.default) {
                    callback(nil)
                }
            }
        }
    }
}
