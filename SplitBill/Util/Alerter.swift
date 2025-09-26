//
//  Alerter.swift
//  SplitBill
//
//  Created by fer0n on 20.02.23.
//

import Foundation
import SwiftUI
import Observation

@Observable class Alerter {
    var alert: Alert? {
        didSet { isShowingAlert = alert != nil }
    }
    var isShowingAlert = false
}
