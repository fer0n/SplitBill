//
//  SettingsSheet.swift
//  SplitBill
//

import SwiftUI

struct SettingsSheet: ViewModifier {
    @Binding var show: Bool

    func body(content: Content) -> some View {
        content.sheet(isPresented: $show) {
            SettingsView()
                .ignoresSafeArea()
        }
    }
}

extension View {
    func settingsSheet(show: Binding<Bool>) -> some View {
        self.modifier(SettingsSheet(show: show))
    }
}

#Preview {
    ZStack {
        Color.red
    }
    .settingsSheet(
        show: .constant(true),
        )
    .environmentObject(ContentViewModel())
}
