//
//  LinkItemView.swift
//  SplitBill
//

import SwiftUI

struct LinkItemView<Content: View>: View {
    let destination: URL
    let label: String
    let content: () -> Content

    var body: some View {
        Link(destination: destination) {
            HStack(spacing: 20) {
                content()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.labelColor)
                Text(LocalizedStringKey(label))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.labelColor)
            }
        }
    }
}
