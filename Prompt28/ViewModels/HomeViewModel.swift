import SwiftUI
import Observation

@Observable
final class HomeViewModel {
    var selectedMode: PromptMode = .ai
    var isRecording = false

    func toggleRecording() {
        isRecording.toggle()
    }

    func openSettings() {
        // hook up later
    }
}
