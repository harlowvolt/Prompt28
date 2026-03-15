import SwiftUI

/// OrionSettingsView - Modern settings view for Orion Orb
@MainActor
struct OrionSettingsView: View {
    @AppStorage("hasAcceptedPrivacy") private var hasAcceptedPrivacy = false
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true
    @State private var showPrivacySheet = false
    @State private var showOnboardingSheet = false
    @State private var notificationsEnabled = true
    @State private var hapticsEnabled = true
    
    var body: some View {
        ZStack {
            // Background
            PromptPremiumBackground()
                .ignoresSafeArea()
            
            List {
                // Account Section
                Section {
                    accountRow
                } header: {
                    Text("Account")
                        .textCase(.uppercase)
                }
                
                // Preferences Section
                Section {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Notifications", systemImage: "bell.fill")
                    }
                    
                    Toggle(isOn: $hapticsEnabled) {
                        Label("Haptic Feedback", systemImage: "hand.tap.fill")
                    }
                } header: {
                    Text("Preferences")
                        .textCase(.uppercase)
                }
                
                // App Section
                Section {
                    Button(action: { showOnboardingSheet = true }) {
                        Label("Replay Onboarding", systemImage: "play.circle.fill")
                    }
                    
                    Button(action: { showPrivacySheet = true }) {
                        Label("Privacy Policy", systemImage: "lock.shield.fill")
                    }
                    
                    NavigationLink(destination: UpgradeView(viewModel: SettingsViewModel())) {
                        Label("Upgrade to Pro", systemImage: "star.circle.fill")
                            .foregroundStyle(.purple)
                    }
                } header: {
                    Text("App")
                        .textCase(.uppercase)
                }
                
                // About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle.fill")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                            .monospaced()
                    }
                    
                    Link(destination: URL(string: "https://orionorb.app")!) {
                        Label("Website", systemImage: "globe")
                    }
                    
                    Link(destination: URL(string: "mailto:support@orionorb.app")!) {
                        Label("Contact Support", systemImage: "envelope.fill")
                    }
                } header: {
                    Text("About")
                        .textCase(.uppercase)
                }
                
                // Danger Zone
                Section {
                    Button(role: .destructive, action: clearHistory) {
                        Label("Clear History", systemImage: "trash.fill")
                    }
                    
                    Button(role: .destructive, action: resetApp) {
                        Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                    }
                } header: {
                    Text("Danger Zone")
                        .textCase(.uppercase)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showPrivacySheet) {
            PrivacyConsentView(onAccept: { showPrivacySheet = false })
        }
        .sheet(isPresented: $showOnboardingSheet) {
            OnboardingView(onComplete: { showOnboardingSheet = false })
        }
    }
    
    // MARK: - Components
    
    private var accountRow: some View {
        HStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(Color.purple.gradient)
                    .frame(width: 56, height: 56)
                
                Text("U")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("User")
                    .font(.headline)
                
                Text("Free Plan")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            NavigationLink(destination: EmptyView()) {
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Properties
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // MARK: - Actions
    
    private func clearHistory() {
        // Clear history implementation
        HapticService.impact(.heavy)
    }
    
    private func resetApp() {
        // Reset app implementation
        hasAcceptedPrivacy = false
        hasSeenOnboarding = false
        HapticService.impact(.heavy)
    }
}

// MARK: - Preview

#Preview("Orion Settings") {
    NavigationStack {
        OrionSettingsView()
    }
}
