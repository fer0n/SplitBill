//
//  EditCardSheet.swift
//  SplitBill
//

import SwiftUI

struct EditCardSheet: ViewModifier {
    @Binding var show: Bool
    @Environment(\.dismiss) var dismiss

    func body(content: Content) -> some View {
        content.sheet(isPresented: $show) {
            // Workaround: in iOS 17, having a List { TextField(...) } breaks the partial sheet
            // A partial sheet can be used again if/once this gets fixed by Apple
            NavigationStack {
                EditCardsView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                show = false
                            } label: {
                                Image(systemName: "xmark")
                            }
                        }
                    }
                    .navigationTitle("editCards")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

extension View {
    func editCardsSheet(show: Binding<Bool>) -> some View {
        self.modifier(EditCardSheet(show: show))
    }
}

#Preview {
    ZStack {}
        .editCardsSheet(show: .constant(true))
        .environmentObject(ContentViewModel())
}
