import SwiftUI
import UIKit
import GoogleSignIn

@MainActor
@main
struct OrionOrbApp: App {
    // 1. Using @State for the only two things that matter right now
    @State private var env: AppEnvironment
    @State private var errorState: ErrorState

    init() {
        // 2. Clean initialization to satisfy Swift 6
        let initialEnv = AppEnvironment()
        self._env = State(initialValue: initialEnv)
        self._errorState = State(initialValue: ErrorState())
        
        // 3. Set the background color so we know the app is running
        UIWindow.appearance().backgroundColor = UIColor(red: 14/255, green: 12/255, blue: 22/255, alpha: 1)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(env)
                .environment(errorState)
                .environment(\.authManager, env.authManager)
                .environment(\.appRouter, env.router)
                .environment(\.errorState, errorState)
                .environment(\.apiClient, env.apiClient)
                .environment(\.preferencesStore, env.preferencesStore)
                .environment(\.historyStore, env.historyStore)
                .environment(\.usageTracker, env.usageTracker)
                .environment(\.storeManager, env.storeManager)
                .environment(\.keychainService, env.keychain)
                .environment(\.telemetryService, env.telemetryService)
                .environment(\.orbEngineFactory, env.orbEngineFactory)
                .environment(\.speechRecognizerFactory, env.speechRecognizerFactory)
                .environment(\.supabase, env.supabase)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
