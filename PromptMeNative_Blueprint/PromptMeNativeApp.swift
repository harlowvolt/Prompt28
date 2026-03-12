import SwiftUI
import UIKit
import GoogleSignIn

@main
struct PromptMeNativeApp: App {
    @State private var env = AppEnvironment()
    @State private var errorState = ErrorState()

    init() {
        UIWindow.appearance().backgroundColor = UIColor(red: 14/255, green: 12/255, blue: 22/255, alpha: 1)
        UIView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self]).backgroundColor = .clear
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .environment(\.historyStore, env.historyStore)
                .environment(\.authManager, env.authManager)
                .environment(\.appRouter, env.router)
                .environment(\.errorState, errorState)
                .environment(\.apiClient, env.apiClient)
                .onOpenURL { url in
                    // Hands Google's OAuth redirect back to the SDK
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
