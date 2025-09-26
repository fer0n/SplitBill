//
//  SettingsView.swift
//  SplitBill
//
//  Created by fer0n on 21.12.22.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var cvm: ContentViewModel
    @AppStorage("startupItem") var startupItem: StartupItem = .scanner

    let writeReviewUrl = URL(string: "https://apps.apple.com/app/id6444704240?action=write-review")!
    let emailUrl = URL(string: "mailto:scores.templates@gmail.com")!
    let githubUrl = URL(string: "https://github.com/fer0n/SplitBill")!

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("openOnStartUp", selection: $startupItem) {
                        ForEach(StartupItem.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Toggle(isOn: $cvm.flashTransactionValue) {
                        Text("flashTransactionValue")
                    }
                    .tint(.markerColor)
                    Picker("previewDuration", selection: $cvm.previewDuration) {
                        ForEach(PreviewDuration.allCases, id: \.self) {
                            Text($0.description)
                        }
                    }
                    .pickerStyle(.menu)
                    .disabled(!cvm.flashTransactionValue)
                }

                Section {
                    LinkItemView(destination: writeReviewUrl, label: "rateApp") {
                        Image(systemName: "star.fill")
                    }

                    LinkItemView(destination: emailUrl, label: "contact") {
                        Image(systemName: "envelope.fill")
                    }

                    LinkItemView(destination: githubUrl, label: "github") {
                        Image("github-logo")
                            .resizable()
                    }
                }
            }
            .navigationBarTitle("settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

enum PreviewDuration: Int, CaseIterable {
    case short
    case medium
    case long
    case tapAway

    var description: String {
        switch self {
        case .short: return String(localized: "short")
        case .medium: return String(localized: "medium")
        case .long: return String(localized: "long")
        case .tapAway: return String(localized: "tapAway")
        }
    }

    var timeInterval: TimeInterval? {
        switch self {
        case .short: return 0.5
        case .medium: return 2.5
        case .long: return 5
        case .tapAway: return nil
        }
    }
}

enum StartupItem: Int, CaseIterable {
    case nothing
    case scanner
    case imagePicker

    var description: String {
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

#Preview {
    SettingsView()
        .environmentObject(ContentViewModel())
}
