import SwiftUI

@main
struct SplitBillApp: App {
    @State var alerter = Alerter()
    @StateObject var cvm = ContentViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(alerter)
                .alert(isPresented: $alerter.isShowingAlert) {
                    alerter.alert ?? Alert(title: Text(""))
                }
                .environmentObject(cvm)
        }
    }
}
