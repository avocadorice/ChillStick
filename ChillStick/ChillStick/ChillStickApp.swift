import SwiftUI

@main
struct ChillStickApp: App {
    init() {
        // Prevent screen sleep/dimming during active gameplay
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
