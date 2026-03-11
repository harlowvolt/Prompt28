import GoogleSignIn
import SwiftUI

@main
struct PromptMeNativeApp: App {
    @State private var env = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .onOpenURL { url in
                    // Hands Google's OAuth redirect back to the SDK
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
