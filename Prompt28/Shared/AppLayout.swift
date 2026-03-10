import SwiftUI

enum AppSpacing {
    static let screenHorizontal: CGFloat = 24
    static let section: CGFloat = 20
    static let largeSection: CGFloat = 28
    static let element: CGFloat = 12
    static let top: CGFloat = 24
    static let bottomContentClearance: CGFloat = 110
}

enum AppHeights {
    static let searchBar: CGFloat = 56
    static let segmentedControl: CGFloat = 60
    static let floatingTabBar: CGFloat = 76
    static let orb: CGFloat = 300
    static let typeButton: CGFloat = 60
}

enum AppRadii {
    static let card: CGFloat = 28
    static let pill: CGFloat = 26
    static let field: CGFloat = 22
    static let tabBar: CGFloat = 30
}

struct AppScreenContainer<Content: View>: View {
    let title: String?
    let showsScrollIndicators: Bool
    @ViewBuilder let content: () -> Content

    init(
        title: String? = nil,
        showsScrollIndicators: Bool = false,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.showsScrollIndicators = showsScrollIndicators
        self.content = content
    }

    var body: some View {
        ScrollView(showsIndicators: showsScrollIndicators) {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                if let title {
                    Text(title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                content()
            }
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.top)
            .padding(.bottom, AppSpacing.bottomContentClearance)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.clear)
    }
}
