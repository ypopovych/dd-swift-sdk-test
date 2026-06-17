import SwiftUI

// Minimal host app for the unit-test bundle. The SDK is linked into the test
// target, not the app, so this is just a placeholder window.
@main
struct Issue280ReproApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Issue 280 repro – run the tests")
                .padding()
                .frame(minWidth: 320, minHeight: 120)
        }
    }
}
