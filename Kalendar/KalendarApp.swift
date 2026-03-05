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
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
    }
}
