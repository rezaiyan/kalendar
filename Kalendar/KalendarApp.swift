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
    
    init() {
        // Force refresh widgets on app launch to ensure they're up to date
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    // Handle widget refresh URLs
                    if url.scheme == "kalendar-refresh" {
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }
        }
    }
}
