import Foundation
import Combine
import CoreGraphics
import Speech
import AVFoundation

@MainActor
final class SpeechRecognizer: ObservableObject, SpeechRecognizing {
    @Published private(set) var speechPermissionStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined

    private let service: SpeechRecognizerService

    init(locale: Locale = .current) {
        self.service = SpeechRecognizerService(locale: locale)
    }

    var isRecording: Bool { service.isRecording }
    var transcript: String { service.transcript }
    var finalTranscript: String { service.finalTranscript }
    var permissionStatus: SpeechRecognizerService.PermissionStatus { service.permissionStatus }
    var audioLevel: CGFloat { service.audioLevel }

    var isRecordingPublisher: AnyPublisher<Bool, Never> { service.isRecordingPublisher }
    var transcriptPublisher: AnyPublisher<String, Never> { service.transcriptPublisher }
    var finalTranscriptPublisher: AnyPublisher<String, Never> { service.finalTranscriptPublisher }
    var permissionStatusPublisher: AnyPublisher<SpeechRecognizerService.PermissionStatus, Never> { service.permissionStatusPublisher }
    var audioLevelPublisher: AnyPublisher<CGFloat, Never> { service.audioLevelPublisher }

    func startRecording() {
        service.startRecording()
    }

    func stopRecording() {
        service.stopRecording()
    }

    func reset() {
        service.reset()
    }

    func requestPermissions() {
        DispatchQueue.global(qos: .userInitiated).async {
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    self.speechPermissionStatus = status
                }
            }

            AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        }
    }
}
