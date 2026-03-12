import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.authManager) private var scopedAuthManager
    @Environment(\.historyStore) private var scopedHistoryStore
    @Environment(\.appRouter) private var scopedRouter
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = SettingsViewModel()
    @State private var showUpgrade = false
    @State private var showDeleteConfirm = false
    var onDone: (() -> Void)? = nil

    private var authManager: AuthManager {
        scopedAuthManager ?? env.authManager
    }

    private var historyStore: any HistoryStoring {
        scopedHistoryStore ?? env.historyStore
    }

    private var router: AppRouter {
        scopedRouter ?? env.router
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PromptPremiumBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        headerRow

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

                        logoutButton
                        deleteButton
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .fill(PromptTheme.glassFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 30, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                            )
                    )
                    .padding(.horizontal, 12)
                    .padding(.top, proxy.safeAreaInsets.top + 10)
                    .padding(.bottom, 28)
                }
            }
        }
        .task {
            viewModel.bind(
                apiClient: env.apiClient,
                authManager: authManager,
                preferencesStore: env.preferencesStore,
                historyStore: historyStore
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
                        router.rootRoute = .auth
                    }
                }
            }
        }
    }

    private var headerRow: some View {
        HStack {
            Text("Settings")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            Spacer()

            Button {
                if let onDone {
                    onDone()
                } else {
                    dismiss()
                }
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.86))
                    .padding(.horizontal, 20)
                        .frame(height: 44)
                    .background(
                        Capsule()
                            .fill(PromptTheme.glassFill)
                            .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                    )
            }
            .buttonStyle(.plain)
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
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                        .frame(width: 58, height: 58)
                    Text(avatarInitials)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                }

                VStack(alignment: .leading, spacing: 3) {
                    if let name = authManager.currentUser?.name, !name.isEmpty {
                        Text(name)
                            .font(PromptTheme.Typography.rounded(18, .semibold))
                            .foregroundStyle(PromptTheme.paleLilacWhite)
                    }
                    Text(authManager.currentUser?.email ?? "—")
                        .font(PromptTheme.Typography.rounded(14, .regular))
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
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                        .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                )
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(PromptTheme.glassCard(cornerRadius: 24))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        VStack(spacing: 0) {
            sectionHeader("Subscription")
            VStack(spacing: 14) {
                HStack {
                    Text(authManager.currentUser?.plan.rawValue.capitalized ?? "Starter")
                        .font(PromptTheme.Typography.rounded(16, .semibold))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                    Spacer()
                    Text((authManager.currentUser?.plan.rawValue ?? "starter").uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(
                            Capsule()
                                .fill(PromptTheme.mutedViolet.opacity(0.38))
                                .overlay(Capsule().stroke(PromptTheme.softLilac.opacity(0.30), lineWidth: 0.5))
                        )
                }

                if let user = authManager.currentUser, let remaining = user.prompts_remaining {
                    let total = Double(user.prompts_used + remaining)
                    let fraction = total > 0 ? Double(user.prompts_used) / total : 0.0

                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.10))
                                    .frame(height: 8)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [PromptTheme.mutedViolet, PromptTheme.softLilac.opacity(0.80)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(8, geo.size.width * fraction), height: 8)
                            }
                        }
                        .frame(height: 8)

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
                        .frame(height: 58)
                        .background {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#7F7FD5"), Color(hex: "#6E55D8")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .stroke(PromptTheme.softLilac.opacity(0.28), lineWidth: 0.5)
                                )
                        }
                }
                .buttonStyle(.plain)

                if authManager.currentUser?.plan == .dev {
                    Button("Reset Usage") {
                        Task { await viewModel.resetUsage() }
                    }
                    .font(PromptTheme.Typography.rounded(13, .medium))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.65))
                }
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .background(PromptTheme.glassCard(cornerRadius: 24))
    }

    // MARK: - App Section

    private var appSection: some View {
        VStack(spacing: 0) {
            sectionHeader("App")
            VStack(spacing: 0) {
                settingsToggleRow(
                    label: "AI Mode (default)",
                    subtitle: "Standard expert prompt style",
                    isOn: Binding(
                        get: { viewModel.selectedMode == .ai },
                        set: { viewModel.selectedMode = $0 ? .ai : .human }
                    ),
                    isLast: false
                )
                settingsToggleRow(
                    label: "Save History",
                    subtitle: "Store prompts on this device",
                    isOn: $viewModel.saveHistory,
                    isLast: true
                )
            }
        }
        .background(PromptTheme.glassCard(cornerRadius: 24))
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
        .background(PromptTheme.glassCard(cornerRadius: 24))
    }

    // MARK: - Action Buttons

    private var logoutButton: some View {
        Button {
            authManager.logout()
            router.rootRoute = .auth
        } label: {
            Text("Log Out")
                .font(PromptTheme.Typography.rounded(16, .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 64)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(red: 0.72, green: 0.15, blue: 0.20).opacity(0.30))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                .frame(height: 64)
                .background {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.red.opacity(0.18), lineWidth: 1)
                        )
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reusable Rows

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.40))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 8)
    }

    private func settingsToggleRow(label: String, subtitle: String, isOn: Binding<Bool>, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(PromptTheme.Typography.rounded(16, .semibold))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                    Text(subtitle)
                        .font(PromptTheme.Typography.rounded(14, .regular))
                        .foregroundStyle(.white.opacity(0.58))
                }
                Spacer()
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .tint(PromptTheme.mutedViolet)
            }
            .padding(.horizontal, 18)
            .frame(minHeight: 96)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
            }
        }
    }

    private func legalLinkRow(label: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        VStack(spacing: 0) {
            Button(action: action) {
                HStack {
                    Text(label)
                        .font(PromptTheme.Typography.rounded(16, .medium))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.55))
                }
                .padding(.horizontal, 18)
                .frame(height: 64)
            }
            .buttonStyle(.plain)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
                    .padding(.horizontal, 18)
            }
        }
    }

    // MARK: - Helpers

    private var avatarInitials: String {
        let name = authManager.currentUser?.name ?? ""
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        } else if let first = parts.first {
            return String(first.prefix(2)).uppercased()
        }
        return "?"
    }
}
