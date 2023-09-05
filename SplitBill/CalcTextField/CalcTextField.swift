//
//  CalcTextField.swift
//  ScorePad
//
//  Created by fer0n on 12.07.21.
//


import Foundation
import SwiftUI

struct CalcTextField: UIViewRepresentable {
    
    let textField: UITextField
    var placeholder: String
    @Binding var text: String
    let onSubmit: (Double?) -> ()
    let onEditingChanged: (Bool) -> ()
    var accentColor: UIColor
    var bgColor: UIColor
    var textColor: UIColor
    var font: UIFont
    var alignment: NSTextAlignment
    let isPadded: Bool? = false
    
    init(_ placeholder: String,
         text: Binding<String>,
         onSubmit: @escaping (Double?) -> Void,
         onEditingChanged: @escaping (Bool) -> Void,
         accentColor: UIColor,
         bgColor: UIColor,
         textColor: UIColor,
         font: UIFont = .rounded(ofSize: 18, weight: .medium),
         alignment: NSTextAlignment = .left,
         isPadded: Bool = false) {
        self.placeholder = placeholder
        self._text = text
        self.onSubmit = onSubmit
        self.onEditingChanged = onEditingChanged
        self.accentColor = accentColor
        self.bgColor = bgColor
        self.textColor = textColor
        self.font = font
        self.alignment = alignment
        self.textField = isPadded ? PaddedUITextField() : UITextField()
    }
        
    func makeUIView(context: UIViewRepresentableContext<CalcTextField>) -> UITextField {
        let keyboardView = CalcKeyboard(frame: CGRect(x: 0, y: 0, width: 0, height: 350))
        let delegate = VC_CalcKeyboard()
        delegate.textField = self.textField
        delegate.onSubmit = self.onSubmit
        keyboardView.setAccentColor(color: accentColor, bgColor: bgColor)
        keyboardView.delegate = delegate
        
        textField.inputView = keyboardView
        textField.textAlignment = alignment
        textField.font = font
        textField.placeholder = placeholder
        textField.delegate = context.coordinator
        textField.textColor = textColor
        
        textField.addTarget(context.coordinator, action: #selector(context.coordinator.textChanged), for: .editingChanged)
        
        return textField
    }
    

    func updateUIView(_ uiView: UITextField, context: UIViewRepresentableContext<CalcTextField>) {
        if (uiView.text != text) {
            uiView.text = text
        }
        
        uiView.textColor = self.textColor
    }
    
    func makeCoordinator() -> CalcTextField.Coordinator {
        Coordinator(parent: self, onEditingChanged: self.onEditingChanged)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CalcTextField
        let onEditingChanged: (Bool) -> ()

        init(parent: CalcTextField,
             onEditingChanged: @escaping (Bool) -> ()) {
            self.parent = parent
            self.onEditingChanged = onEditingChanged
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            self.onEditingChanged(true)
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            self.onEditingChanged(false)
        }
        
        @objc func textChanged(_ sender: UITextField) {
            guard let text = sender.text else { return }
            self.parent.text = text
        }
    }
}



@IBDesignable
class PaddedUITextField: UITextField {
    @IBInspectable var insetX: CGFloat = 5
    @IBInspectable var insetY: CGFloat = 0

    // placeholder position
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: insetX, dy: insetY)
    }

    // text position
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: insetX, dy: insetY)
    }
}

