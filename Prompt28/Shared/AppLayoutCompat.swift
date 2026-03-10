import SwiftUI

// Compatibility aliases for existing screens.
extension AppSpacing {
    static let screenTopLarge: CGFloat = largeSection
    static let sectionTight: CGFloat = 16
    static let cardInset: CGFloat = 22
    static let elementTight: CGFloat = 8
}

extension AppHeights {
    static let searchField: CGFloat = searchBar
    static let segmented: CGFloat = segmentedControl
    static let primaryButton: CGFloat = typeButton
    static let tabBarFloating: CGFloat = floatingTabBar
    static let tabBarClearance: CGFloat = AppSpacing.bottomContentClearance
}

extension AppRadii {
    static let control: CGFloat = pill
    static let chip: CGFloat = 10
}

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
            .shadow(color: .black.opacity(0.48), radius: 18, y: 12)
    }
}
