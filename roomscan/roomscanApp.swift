//
//  storageApp.swift
//  storage
//
//  Created by Andrés on 28/6/2025.
//

import SwiftUI
import SwiftData

@main   
struct roomscanApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WishListItem.self,
        ])
        
        // Configure for CloudKit   
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.aguilarcarboni.roomscan")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
