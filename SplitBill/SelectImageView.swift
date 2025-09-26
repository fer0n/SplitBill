//
//  SelectImageView.swift
//  SplitBill
//

import SwiftUI

struct SelectImageView: View {
    @Binding var showImagePicker: Bool
    @Binding var showScanner: Bool

    var body: some View {
        VStack {
            Spacer()
                .frame(height: 40)
            Button {
                self.showImagePicker = true
            } label: {
                Image(systemName: "photo.fill.on.rectangle.fill")
                Spacer()
                Text("selectImage")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding([.vertical], 10)
            .padding([.horizontal], 15)
            .frame(maxWidth: .infinity)
            .background(.white)
            .foregroundColor(Color.mainColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button {
                self.showScanner = true
            } label: {
                Image(systemName: "doc.viewfinder.fill")
                Spacer()
                Text("openScanner")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
            }
            .padding([.vertical], 10)
            .padding([.horizontal], 15)
            .frame(maxWidth: .infinity)
            .background(.white)
            .foregroundColor(Color.mainColor)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .fixedSize()
    }
}
