import SwiftUI

@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            // Egyedi menüpontok szükség esetén
            CommandGroup(replacing: .newItem) { }
        }
    }
}
