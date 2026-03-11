import GoogleSignIn
import SwiftUI
import UIKit

@main
struct PromptMeNativeApp: App {
    @State private var env = AppEnvironment()

    init() {
        // 1. Sets the actual iOS Window background to match your theme
        UIWindow.appearance().backgroundColor = UIColor(PromptTheme.backgroundBase)

        // 2. Makes the SwiftUI container background transparent so the window color shows through
        UIView.appearance(whenContainedInInstancesOf: [UIHostingController.self]).backgroundColor = .clear
    }

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
