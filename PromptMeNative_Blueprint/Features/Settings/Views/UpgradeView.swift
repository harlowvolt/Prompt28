import SwiftUI
import StoreKit

struct UpgradeView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var env: AppEnvironment
    @ObservedObject var viewModel: SettingsViewModel

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                PromptPremiumBackground()
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        headerSection
                        productList
                        restoreButton
                        devSection
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Upgrade")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(PromptTheme.softLilac)
                }
            }
        }
        .task { await env.storeManager.loadProducts() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 10) {
            Image(systemName: "sparkles")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [PromptTheme.softLilac, PromptTheme.paleLilacWhite],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Unlock More Prompts")
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)

            Text("Keep the ideas flowing with a Pro or Unlimited plan.")
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Product List

    @ViewBuilder
    private var productList: some View {
        if env.storeManager.products.isEmpty {
            VStack(spacing: 14) {
                ProgressView()
                    .tint(PromptTheme.softLilac)
                Text("Loading plans…")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(PromptTheme.softLilac.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        } else {
            VStack(spacing: 14) {
                ForEach(env.storeManager.products, id: \.id) { product in
                    ProductCard(product: product, storeManager: env.storeManager, viewModel: viewModel)
                }
            }
        }

        if let error = env.storeManager.errorMessage {
            Text(error)
                .font(.system(size: 13, design: .rounded))
                .foregroundStyle(.red.opacity(0.85))
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Restore

    private var restoreButton: some View {
        Button {
            Task { await env.storeManager.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.72))
        }
        .buttonStyle(.plain)
        .disabled(env.storeManager.isPurchasing)
    }

    // MARK: - Dev section (DEBUG / admin only)

    @ViewBuilder
    private var devSection: some View {
        #if DEBUG
        Divider()
            .overlay(PromptTheme.softLilac.opacity(0.2))

        VStack(alignment: .leading, spacing: 10) {
            Text("Dev Plan (internal)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.55))

            SecureField("Admin key", text: $viewModel.devAdminKey)
                .font(.system(size: 14, design: .monospaced))
                .padding(10)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(PromptTheme.softLilac.opacity(0.18), lineWidth: 1))

            Button(viewModel.isSaving ? "Saving…" : "Activate Dev Plan") {
                Task {
                    viewModel.selectedPlan = .dev
                    let updated = await viewModel.updatePlan()
                    if updated { dismiss() }
                }
            }
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(PromptTheme.softLilac)
            .disabled(viewModel.isSaving || viewModel.devAdminKey.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        #endif
    }
}

// MARK: - ProductCard

private struct ProductCard: View {
    let product: Product
    @ObservedObject var storeManager: StoreManager
    @ObservedObject var viewModel: SettingsViewModel

    @State private var isPurchasing = false
    @EnvironmentObject private var env: AppEnvironment

    private var planLabel: String {
        switch product.id {
        case StoreProductID.proMonthly:       return "Pro"
        case StoreProductID.proYearly:        return "Pro"
        case StoreProductID.unlimitedMonthly: return "Unlimited"
        case StoreProductID.unlimitedYearly:  return "Unlimited"
        default: return product.displayName
        }
    }

    private var billingLabel: String {
        product.id.contains("yearly") ? "/ year" : "/ month"
    }

    private var perks: [String] {
        switch product.id {
        case StoreProductID.proMonthly, StoreProductID.proYearly:
            return ["500 prompts / month", "AI & Human mode", "Full history & favorites"]
        case StoreProductID.unlimitedMonthly, StoreProductID.unlimitedYearly:
            return ["Unlimited prompts", "Priority generation", "Everything in Pro"]
        default:
            return []
        }
    }

    private var isYearly: Bool { product.id.contains("yearly") }
    private var isPurchased: Bool { storeManager.purchasedProductIDs.contains(product.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title row
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(planLabel)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(PromptTheme.paleLilacWhite)
                        if isYearly {
                            Text("BEST VALUE")
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(PromptTheme.softLilac, in: Capsule())
                        }
                    }
                    Text(product.description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(product.displayPrice)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(PromptTheme.paleLilacWhite)
                    Text(billingLabel)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.6))
                }
            }

            // Perks
            if !perks.isEmpty {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(perks, id: \.self) { perk in
                        HStack(spacing: 7) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(PromptTheme.softLilac.opacity(0.75))
                            Text(perk)
                                .font(.system(size: 13, design: .rounded))
                                .foregroundStyle(PromptTheme.paleLilacWhite.opacity(0.85))
                        }
                    }
                }
            }

            // Purchase button
            Button {
                Task { await handlePurchase() }
            } label: {
                HStack {
                    if isPurchased {
                        Image(systemName: "checkmark")
                        Text("Purchased")
                    } else if isPurchasing || storeManager.isPurchasing {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("Processing…")
                    } else {
                        Text("Subscribe \(billingLabel)")
                    }
                }
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    isPurchased
                    ? AnyShapeStyle(PromptTheme.mutedViolet.opacity(0.35))
                    : AnyShapeStyle(LinearGradient(
                        colors: [PromptTheme.mutedViolet, PromptTheme.softLilac.opacity(0.85)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )),
                    in: RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPurchased || isPurchasing || storeManager.isPurchasing)
        }
        .padding(18)
        .background { PromptTheme.glassCard(cornerRadius: AppRadii.card) }
        .overlay(
            RoundedRectangle(cornerRadius: AppRadii.card, style: .continuous)
                .stroke(
                    isYearly ? PromptTheme.softLilac.opacity(0.38) : Color.white.opacity(0.10),
                    lineWidth: isYearly ? 1.2 : 1
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 12, y: 8)
    }

    private func handlePurchase() async {
        isPurchasing = true
        defer { isPurchasing = false }

        let success = await storeManager.purchase(product)
        guard success else { return }

        // Sync the purchased plan back to the backend
        if let planType = storeManager.planType(for: product.id) {
            viewModel.selectedPlan = planType
            _ = await viewModel.updatePlan()
        }
    }
}
