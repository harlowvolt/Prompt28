import SwiftUI
import UIKit
import GoogleSignIn

@main
struct PromptMeNativeApp: App {
    @State private var env = AppEnvironment()

    init() {
        // 1. Sets the actual iOS Window background to match your theme
        // This ensures the "void" behind SwiftUI matches your dark navy aesthetic
        UIWindow.appearance().backgroundColor = UIColor(PromptTheme.backgroundBase)
        
        // 2. Makes the SwiftUI container background transparent
        // Using <AnyView> fixes the 'Generic parameter Content could not be inferred' error
        UIView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self]).backgroundColor = .clear
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
