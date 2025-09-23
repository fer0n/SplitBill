//
//  SettingsSheet.swift
//  SplitBill
//

import SwiftUI

struct SettingsSheet: ViewModifier {
    @Binding var show: Bool
    @ObservedObject var cvm: ContentViewModel

    func body(content: Content) -> some View {
        content.sheet(isPresented: $show) {
            SettingsView(cvm: cvm)
                .ignoresSafeArea()
        }
    }
}

extension View {
    func settingsSheet(show: Binding<Bool>, cvm: ContentViewModel) -> some View {
        self.modifier(SettingsSheet(show: show, cvm: cvm))
    }
}

#Preview {
    ZStack {
        Color.red
    }
    .settingsSheet(
        show: .constant(true),
        cvm: ContentViewModel(),
        )
}
