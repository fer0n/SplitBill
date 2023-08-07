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



struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(vm: ContentViewModel(), showSelf: .constant(true))
    }
}
