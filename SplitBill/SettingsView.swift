//
//  SettingsView.swift
//  SplitBill
//
//  Created by fer0n on 21.12.22.
//

import SwiftUI



struct SettingsView: View {
    @ObservedObject var vm: ContentViewModel
    @Binding var showSelf: Bool
    
    var body: some View {
        NavigationView {
            List {
                Picker("openOnStartUp", selection: $vm.startupItem) {
                    ForEach(StartupItem.allCases, id: \.self) {
                        Text($0.description)
                    }
                }
                .pickerStyle(.menu)
                Toggle(isOn: $vm.flashTransactionValue) {
                    Text("flashTransactionValue")
                }
                .tint(.markerColor)
                
                
                Section {
                    LinkItemView(destination: URL(string: "https://apps.apple.com/app/id6444704240?action=write-review")!, label: "rateApp") {
                        Image(systemName: "star.fill")
                    }
                    
                    LinkItemView(destination: URL(string: "mailto:scores.templates@gmail.com")!, label: "contact") {
                        Image(systemName: "envelope.fill")
                    }
                    
                    LinkItemView(destination: URL(string: "https://github.com/fer0n/SplitBill")!, label: "github") {
                        Image("github-logo")
                            .resizable()
                    }
                }
            }
            .navigationBarTitle("settings")
        }
        
    }
}



enum StartupItem: Int, CaseIterable {
    case nothing
    case scanner
    case imagePicker
    
    var description : String {
        switch self {
        case .nothing: return String(localized: "nothing")
        case .scanner: return String(localized: "scanner")
        case .imagePicker: return String(localized: "imagePicker")
        }
    }
}


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



struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(vm: ContentViewModel(), showSelf: .constant(true))
    }
}


