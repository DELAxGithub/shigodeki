//
//  shigodekiApp.swift
//  shigodeki
//
//  Created by Hiroshi Kodera on 2025-08-27.
//

import SwiftUI
import FirebaseCore

@main
struct shigodekiApp: App {
    let persistenceController = PersistenceController.shared
    
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
