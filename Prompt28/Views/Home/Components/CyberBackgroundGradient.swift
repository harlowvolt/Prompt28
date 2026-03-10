import SwiftUI

struct CyberBackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [.cyberBlack, .deepPurple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
