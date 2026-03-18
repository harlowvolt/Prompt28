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
            // 4. We use a local view to bypass all "Cannot find in scope" errors
            ZStack {
                Color(red: 14/255, green: 12/255, blue: 22/255).ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Circle()
                        .fill(LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 80, height: 80)
                        .shadow(color: .purple.opacity(0.5), radius: 10)
                    
                    Text("ORION ORB 2.5")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("ENVIRONMENT LOADED")
                        .font(.caption)
                        .tracking(2)
                        .foregroundColor(.gray)
                }
            }
            .environment(env) // This injects the WHOLE environment
            .environment(errorState)
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
