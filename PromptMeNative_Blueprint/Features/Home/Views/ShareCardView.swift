import SwiftUI

struct ShareCardView: View {
    let rawInput: String
    let generatedPrompt: String
    let modeName: String

    private var cleanedRawInput: String {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Voice input" : trimmed
    }

    private var cleanedGeneratedPrompt: String {
        let trimmed = generatedPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Generated prompt" : trimmed
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Turned a messy thought into an AI-ready prompt.")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 6) {
                Text("BEFORE")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.5))

                Text(cleanedRawInput)
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(4)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("AFTER")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.5))

                Text(cleanedGeneratedPrompt)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(8)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .background(Color.purple.opacity(0.25))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer(minLength: 0)

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("ORBIT ORB")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Refined by Orbit Orb")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                Text(modeName)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(Color.white.opacity(0.2))
                    )
            }
        }
        .padding(24)
        .frame(width: 400, height: 650, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    PromptTheme.plum,
                    PromptTheme.backgroundBase
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
