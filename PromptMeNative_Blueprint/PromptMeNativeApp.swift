import SwiftUI
import UIKit
import GoogleSignIn

@main
struct PromptMeNativeApp: App {
    @State private var env = AppEnvironment()

    init() {
        UIWindow.appearance().backgroundColor = UIColor(red: 14/255, green: 12/255, blue: 22/255, alpha: 1)
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
