import SwiftUI
import UIKit
import GoogleSignIn

@main
struct OrionOrbApp: App {
    @State private var env = AppEnvironment()
    @State private var errorState = ErrorState()

    init() {
        UIWindow.appearance().backgroundColor = UIColor(red: 14/255, green: 12/255, blue: 22/255, alpha: 1)
        UIView.appearance(whenContainedInInstancesOf: [UIHostingController<AnyView>.self]).backgroundColor = .clear
#if !DEBUG
        resetRootBackgroundExperimentFlags()
#endif
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
                .environment(\.preferencesStore, env.preferencesStore)
                .environment(\.usageTracker, env.usageTracker)
                .environment(\.storeManager, env.storeManager)
                .environment(\.keychainService, env.keychain)
                .environment(\.telemetryService, env.telemetryService)
                .environment(\.speechRecognizerFactory, env.speechRecognizerFactory)
                .environment(\.orbEngineFactory, env.orbEngineFactory)
                .onOpenURL { url in
                    // Hands Google's OAuth redirect back to the SDK
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }

    private func resetRootBackgroundExperimentFlags() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: ExperimentFlags.RootBackground.home)
        defaults.set(false, forKey: ExperimentFlags.RootBackground.trending)
        defaults.set(false, forKey: ExperimentFlags.RootBackground.history)
        defaults.set(false, forKey: ExperimentFlags.RootBackground.favorites)
    }
}
