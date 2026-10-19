import SwiftUI

@main
struct KadrApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}
