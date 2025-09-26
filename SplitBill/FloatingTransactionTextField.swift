//
//  FloatingTransactionTextField.swift
//  SplitBill
//

import SwiftUI

struct FloatingTransactionTextField: View {
    @Binding var floatingTransactionInfo: FloatingTransactionInfo
    @Binding var floatingTransaction: Transaction?
    @FocusState.Binding var floatingTransactionIsFocused: Bool
    @Binding var attempts: Int
    var floatingTransactionDisappearTimer: Timer?
    var handleFreeformTransaction: (Transaction?) -> Void

    var body: some View {
        ZStack {
            CalcTextField(
                "",
                text: $floatingTransactionInfo.value,
                onSubmit: { result in
                    guard let res = result else {
                        self.attempts += 1
                        return
                    }
                    if res != 0 {
                        floatingTransactionInfo.value = String(res)
                    }
                },
                onEditingChanged: { edit in
                    if !edit {
                        handleFreeformTransaction(nil)
                    } else {
                        floatingTransactionDisappearTimer?.invalidate()
                    }
                },
                accentColor: floatingTransactionInfo.color.uiColorFont,
                bgColor: UIColor(floatingTransactionInfo.color.dark),
                textColor: UIColor(floatingTransactionInfo.color.contrast),
                font: floatingTransactionInfo.uiFont
            )
            .fixedSize()
            .focused($floatingTransactionIsFocused)
        }
        .floatingTransactionModifier(floatingTransaction, floatingTransactionInfo)
        .modifier(Shake(animatableData: CGFloat(self.attempts)))
    }
}
