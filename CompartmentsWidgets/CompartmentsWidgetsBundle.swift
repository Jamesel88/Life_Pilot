//
//  CompartmentsWidgetsBundle.swift
//  CompartmentsWidgets
//

import WidgetKit
import SwiftUI

@main
struct CompartmentsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayRingsWidget()
        CompartmentBoxWidget()
    }
}
