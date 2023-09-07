import SwiftUI

@main
struct SplitBillApp: App {
    @StateObject var alerter: Alerter = Alerter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(alerter)
                .alert(isPresented: $alerter.isShowingAlert) {
                    alerter.alert ?? Alert(title: Text(""))
                }
        }
    }
}
