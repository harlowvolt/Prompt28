import SwiftUI

/// OrionHomeView - Modern home view for Orion Orb
@MainActor
struct OrionHomeView: View {
    @State private var selectedMode: PromptMode = .ai
    @State private var inputText: String = ""
    @State private var isGenerating: Bool = false
    @State private var showResult: Bool = false
    @State private var generatedResult: String = ""
    
    var body: some View {
        ZStack {
            // Background
            PromptPremiumBackground()
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Mode selector
                    modeSelector
                    
                    // Input area
                    inputSection
                    
                    // Recent history preview
                    historyPreview
                }
                .padding()
            }
        }
        .navigationTitle("Orion Orb")
        .navigationBarTitleDisplayMode(.large)
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "wand.and.stars")
                        .font(.title2)
                        .foregroundStyle(.purple)
                    
                    Text("Transform Your Ideas")
                        .font(.title3.bold())
                    
                    Spacer()
                }
                
                Text("Enter your thoughts and let Orion craft them into polished, professional content.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var modeSelector: some View {
        GlassCard(padding: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Writing Mode")
                    .font(.headline)
                
                Picker("Mode", selection: $selectedMode) {
                    ForEach(PromptMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }
    
    private var inputSection: some View {
        GlassContainer {
            VStack(spacing: 16) {
                TextEditor(text: $inputText)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                
                Divider()
                    .opacity(0.3)
                
                HStack {
                    Spacer()
                    
                    Button(action: generate) {
                        HStack(spacing: 8) {
                            if isGenerating {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            
                            Text(isGenerating ? "Generating..." : "Generate")
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.purple.gradient)
                                .shadow(color: .purple.opacity(0.3), radius: 8, x: 0, y: 4)
                        )
                    }
                    .disabled(inputText.isEmpty || isGenerating)
                    .opacity(inputText.isEmpty ? 0.6 : 1)
                }
            }
        }
    }
    
    private var historyPreview: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent")
                        .font(.headline)
                    
                    Spacer()
                    
                    NavigationLink(destination: HistoryView()) {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundStyle(.purple)
                    }
                }
                
                if generatedResult.isEmpty {
                    emptyHistoryState
                } else {
                    recentItemPreview
                }
            }
        }
    }
    
    private var emptyHistoryState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))
            
            Text("No recent items")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("Your generated content will appear here")
                .font(.caption)
                .foregroundStyle(.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    
    private var recentItemPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Professional", systemImage: "briefcase.fill")
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(6)
                
                Spacer()
                
                Text("Just now")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Text(generatedResult.prefix(100) + "...")
                .font(.subheadline)
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Actions
    
    private func generate() {
        guard !inputText.isEmpty else { return }
        
        isGenerating = true
        
        // Simulate generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            generatedResult = "This is a professionally crafted version of your input: \"\(inputText)\". The content has been enhanced for clarity, impact, and professional tone."
            isGenerating = false
            showResult = true
        }
    }
}

// MARK: - Preview

#Preview("Orion Home") {
    NavigationStack {
        OrionHomeView()
    }
}
