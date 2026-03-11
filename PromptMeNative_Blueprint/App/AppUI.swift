import SwiftUI

enum AppSpacing {
    static let screenHorizontal: CGFloat = 20   // standard side margin — keeps content off screen edges
    static let section: CGFloat = 24
    static let largeSection: CGFloat = 34
    static let element: CGFloat = 12
    static let bottomContentClearance: CGFloat = 88
}

enum AppRadii {
    static let card: CGFloat = 24
}

enum AppHeights {
    static let searchBar: CGFloat = 56
    static let segmentedControl: CGFloat = 42
    static let floatingTabBar: CGFloat = 76
    static let typeButton: CGFloat = 58
}

// MARK: - Shared Layout Compatibility

extension AppSpacing {
    static let top: CGFloat = 0
    static let screenTopLarge: CGFloat = 0
    static let sectionTight: CGFloat = 16
    static let cardInset: CGFloat = 22
    static let elementTight: CGFloat = 8
}

extension AppRadii {
    static let control: CGFloat = 22
    static let field: CGFloat = 18
    static let chip: CGFloat = 10
}

extension AppHeights {
    static let searchField: CGFloat = searchBar
    static let segmented: CGFloat = segmentedControl
    static let primaryButton: CGFloat = 56
    static let tabBarFloating: CGFloat = floatingTabBar
    static let tabBarClearance: CGFloat = 102
}

enum AppShadows {
    static let cardRadius: CGFloat = 18
    static let cardYOffset: CGFloat = 12
}

// MARK: - Reusable Containers

struct AppScreenContainer<Content: View>: View {
    let title: String
    var isScrollable: Bool = true
    var horizontalPadding: CGFloat = 0
    var topSpacing: CGFloat = AppSpacing.screenTopLarge
    var contentSpacing: CGFloat = AppSpacing.section
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PromptPremiumBackground()

                Group {
                    if isScrollable {
                        ScrollView(showsIndicators: false) {
                            layout(proxy: proxy)
                        }
                    } else {
                        layout(proxy: proxy)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private func layout(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: contentSpacing) {
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .padding(.top, proxy.safeAreaInsets.top + topSpacing)

            content()

            Color.clear
                .frame(height: AppHeights.tabBarClearance)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, horizontalPadding)
    }
}

// MARK: - Reusable Controls

struct AppSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: AppSpacing.element) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PromptTheme.softLilac.opacity(0.6))

            TextField(placeholder, text: $text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(PromptTheme.paleLilacWhite)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(PromptTheme.softLilac)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(PromptTheme.softLilac.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: AppHeights.searchField)
        .background {
            RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        }
    }
}

struct AppGlassField<Content: View>: View {
    let isFocused: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 16)
            .frame(height: AppHeights.searchField)
            .background {
                RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous)
                    .fill(Color.white.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.field, style: .continuous)
                            .stroke(
                                isFocused ? PromptTheme.softLilac.opacity(0.50) : Color.white.opacity(0.14),
                                lineWidth: 1
                            )
                    )
            }
            .animation(.easeInOut(duration: 0.18), value: isFocused)
    }
}

struct AppPrimaryButton: View {
    let title: String
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(0.86)
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppHeights.primaryButton)
            .background {
                RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isEnabled
                                ? [PromptTheme.mutedViolet, Color(red: 0.29, green: 0.21, blue: 0.50)]
                                : [PromptTheme.mutedViolet.opacity(0.34), Color(red: 0.29, green: 0.21, blue: 0.50).opacity(0.34)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: AppRadii.control, style: .continuous)
                            .stroke(PromptTheme.softLilac.opacity(isEnabled ? 0.34 : 0.14), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isLoading)
    }
}

extension View {
    func appGlassCard(radius: CGFloat = AppRadii.card) -> some View {
        self
            .background { PromptTheme.glassCard(cornerRadius: radius) }
            .shadow(color: .black.opacity(0.48), radius: AppShadows.cardRadius, y: AppShadows.cardYOffset)
    }
}

extension PromptTheme {
    static func glassCard(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.07))
            .overlay(
                GeometryReader { geo in
                    RadialGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.10), location: 0.0),
                            .init(color: Color.clear, location: 0.55)
                        ],
                        center: UnitPoint(x: 0.15, y: 0.0),
                        startRadius: 0,
                        endRadius: geo.size.width * 0.6
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}
