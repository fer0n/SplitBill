//
//  Alerter.swift
//  SplitBill
//
//  Created by fer0n on 20.02.23.
//

import Foundation
import SwiftUI

class Alerter: ObservableObject {
    @Published var alert: Alert? {
        didSet { isShowingAlert = alert != nil }
    }
    @Published var isShowingAlert = false
}
