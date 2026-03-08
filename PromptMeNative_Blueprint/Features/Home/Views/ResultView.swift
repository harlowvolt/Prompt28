import SwiftUI

struct ResultView: View {
    @ObservedObject var viewModel: GenerateViewModel
    @State private var copied = false

    var body: some View {
        Group {
            if let result = viewModel.latestResult {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Prompt")
                            .font(.headline)

                        Text(result.professional)
                            .textSelection(.enabled)

                        if !result.template.isEmpty {
                            Divider()
                            Text("Template")
                                .font(.headline)
                            Text(result.template)
                                .textSelection(.enabled)
                        }

                        Divider()

                        TextField("Refine request", text: $viewModel.refinementText)
                            .textFieldStyle(.roundedBorder)

                        HStack {
                            Button("Refine") {
                                Task { await viewModel.refine() }
                            }
                            .buttonStyle(.bordered)

                            Button(copied ? "Copied" : "Copy") {
                                UIPasteboard.general.string = result.professional
                                copied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                    copied = false
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                }
            } else {
                ContentUnavailableView("No Result Yet", systemImage: "text.quote")
            }
        }
    }
}
