import SwiftUI
import UIKit
import GoogleSignIn

@MainActor
@main
struct OrionOrbApp: App {
    private let isRunningTests: Bool
    // 1. Using @State for the only two things that matter right now
    @State private var env: AppEnvironment?
    @State private var errorState: ErrorState?

    init() {
        let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
        self.isRunningTests = isRunningTests

        // 2. Clean initialization to satisfy Swift 6
        self._env = State(initialValue: isRunningTests ? nil : AppEnvironment())
        self._errorState = State(initialValue: isRunningTests ? nil : ErrorState())
        
        // 3. Set the background color so we know the app is running
        UIWindow.appearance().backgroundColor = UIColor(red: 14/255, green: 12/255, blue: 22/255, alpha: 1)
    }
    
    var body: some Scene {
        WindowGroup {
            if isRunningTests {
                Color.clear
            } else if let env, let errorState {
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
}
