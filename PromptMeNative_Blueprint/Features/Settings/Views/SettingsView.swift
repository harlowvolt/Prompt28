import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showUpgrade = false
    @State private var showDeleteConfirm = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                accountCard
                subscriptionCard
                appSection
                legalSection

                if let message = viewModel.errorMessage {
                    Text(message)
                        .font(PromptTheme.Typography.rounded(13, .medium))
                        .foregroundStyle(.red.opacity(0.90))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.red.opacity(0.22), lineWidth: 1)
                                )
                        )
                }

                Spacer(minLength: 6)
                logoutButton
                deleteButton
                Color.clear.frame(height: 28)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
        }
        .task {
            viewModel.bind(
                apiClient: env.apiClient,
                authManager: env.authManager,
                preferencesStore: env.preferencesStore,
                historyStore: env.historyStore
            )
            viewModel.syncFromStores()
            await viewModel.loadRemoteSettings()
        }
        .sheet(isPresented: $showUpgrade) {
            UpgradeView(viewModel: viewModel)
        }
        .confirmationDialog("Delete your account permanently?", isPresented: $showDeleteConfirm) {
            Button("Delete Account", role: .destructive) {
                Task {
                    let deleted = await viewModel.deleteAccount()
                    if deleted {
                        env.router.rootRoute = .auth
                    }
                }
            }
        }
    }

    // MARK: - Account Card

    private var accountCard: some View {
        VStack(spacing: 0) {
            sectionHeader("Account")
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(PromptTheme.mutedViolet.opacity(0.38))
                        .overlay(Circle().stroke(PromptTheme.softLilac.opacity(0.22), lineWidth: 1))
                        .frame(width: 50, height: 50)
                    Text(avatarInitials)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let name = env.authManager.currentUser?.name, !name.isEmpty {
                        Text(name)
                            .font(PromptTheme.Typography.rounded(15, .semibold))
                            .foregroundStyle(PromptTheme.paleLilacWhite)
                    }
                    Text(env.authManager.currentUser?.email ?? "—")
                        .font(PromptTheme.Typography.rounded(13, .regular))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.70))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "apple.logo")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Apple")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.55))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .overlay(Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1))
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(PromptTheme.glassCard(cornerRadius: 20))
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        VStack(spacing: 0) {
            sectionHeader("Subscription")
            VStack(spacing: 14) {
                HStack {
                    Text(env.authManager.currentUser?.plan.rawValue.capitalized ?? "Starter")
                        .font(PromptTheme.Typography.rounded(16, .semibold))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                    Spacer()
                    Text((env.authManager.currentUser?.plan.rawValue ?? "starter").uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(PromptTheme.mutedViolet.opacity(0.38))
                                .overlay(Capsule().stroke(PromptTheme.softLilac.opacity(0.30), lineWidth: 1))
                        )
                }

                if let user = env.authManager.currentUser, let remaining = user.prompts_remaining {
                    let total = Double(user.prompts_used + remaining)
                    let fraction = total > 0 ? Double(user.prompts_used) / total : 0.0

                    VStack(spacing: 6) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(height: 6)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [PromptTheme.mutedViolet, PromptTheme.softLilac.opacity(0.80)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(6, geo.size.width * fraction), height: 6)
                            }
                        }
                        .frame(height: 6)

                        HStack {
                            Text("\(user.prompts_used) used")
                                .font(PromptTheme.Typography.rounded(12, .medium))
                                .foregroundStyle(PromptTheme.softLilac.opacity(0.58))
                            Spacer()
                            Text("\(remaining) remaining")
                                .font(PromptTheme.Typography.rounded(12, .medium))
                                .foregroundStyle(PromptTheme.softLilac.opacity(0.58))
                        }
                    }
                }

                Button {
                    showUpgrade = true
                } label: {
                    Text("Upgrade Plan")
                        .font(PromptTheme.Typography.rounded(15, .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [PromptTheme.mutedViolet, Color(red: 0.29, green: 0.21, blue: 0.50)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(PromptTheme.softLilac.opacity(0.28), lineWidth: 1)
                                )
                        }
                }
                .buttonStyle(.plain)

                if env.authManager.currentUser?.plan == .dev {
                    Button("Reset Usage") {
                        Task { await viewModel.resetUsage() }
                    }
                    .font(PromptTheme.Typography.rounded(13, .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.65))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .background(PromptTheme.glassCard(cornerRadius: 20))
    }

    // MARK: - App Section

    private var appSection: some View {
        VStack(spacing: 0) {
            sectionHeader("App")
            VStack(spacing: 0) {
                settingsToggleRow(
                    icon: "sparkles",
                    label: "Default AI Mode",
                    isOn: Binding(
                        get: { viewModel.selectedMode == .ai },
                        set: { viewModel.selectedMode = $0 ? .ai : .human }
                    ),
                    isLast: false
                )
                settingsToggleRow(
                    icon: "clock.arrow.circlepath",
                    label: "Save History",
                    isOn: $viewModel.saveHistory,
                    isLast: true
                )
            }
        }
        .background(PromptTheme.glassCard(cornerRadius: 20))
        .onChange(of: viewModel.saveHistory) { _, _ in viewModel.applyLocalPreferences() }
        .onChange(of: viewModel.selectedMode) { _, _ in viewModel.applyLocalPreferences() }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Legal")
            VStack(spacing: 0) {
                legalLinkRow(label: "Privacy Policy", isLast: false) {
                    if let url = URL(string: "https://prompt28.com/privacy") {
                        UIApplication.shared.open(url)
                    }
                }
                legalLinkRow(label: "Terms of Service", isLast: true) {
                    if let url = URL(string: "https://prompt28.com/terms") {
                        UIApplication.shared.open(url)
                    }
                }
            }
        }
        .background(PromptTheme.glassCard(cornerRadius: 20))
    }

    // MARK: - Action Buttons

    private var logoutButton: some View {
        Button {
            env.authManager.logout()
            env.router.rootRoute = .auth
        } label: {
            Text("Log Out")
                .font(PromptTheme.Typography.rounded(16, .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.72, green: 0.15, blue: 0.20).opacity(0.84))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.red.opacity(0.30), lineWidth: 1)
                        )
                }
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            Text("Delete Account")
                .font(PromptTheme.Typography.rounded(14, .medium))
                .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.44).opacity(0.80))
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.red.opacity(0.18), lineWidth: 1)
                        )
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Rows

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(PromptTheme.softLilac.opacity(0.48))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }

    private func settingsToggleRow(icon: String, label: String, isOn: Binding<Bool>, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.68))
                    .frame(width: 22)
                Text(label)
                    .font(PromptTheme.Typography.rounded(15, .medium))
                    .foregroundStyle(PromptTheme.paleLilacWhite)
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(PromptTheme.mutedViolet)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
        }
    }

    private func legalLinkRow(label: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(label)
                        .font(PromptTheme.Typography.rounded(15, .medium))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.42))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
            }
            .buttonStyle(.plain)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Helpers

    private var avatarInitials: String {
        let name = env.authManager.currentUser?.name ?? ""
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}
