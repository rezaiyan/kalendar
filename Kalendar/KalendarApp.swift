//
//  KalendarApp.swift
//  Kalendar
//
//  Created by Ali Rezaiyan on 18.08.25.
//

import SwiftUI
import WidgetKit

@main
struct KalendarApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .onChange(of: scenePhase) { _, phase in
            // Keep widgets in sync with anything that changed while the app was open.
            if phase == .background {
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
    }
}
