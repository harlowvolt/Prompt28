import CoreGraphics
import Foundation

/// Protocol describing the observable surface of OrbEngine consumed by views.
/// `@MainActor` matches OrbEngine's own isolation; views interact with the
/// engine exclusively on the main actor.
@MainActor
protocol OrbEngineProtocol: AnyObject {

    // MARK: Observable State
    var state: OrbEngine.State { get }
    var isRecording: Bool { get }
    var transcript: String { get }
    var finalTranscript: String { get }
    var permissionStatus: SpeechRecognizerService.PermissionStatus { get }
    var audioLevel: CGFloat { get }

    // MARK: Derived State
    var needsPermissionSettingsAction: Bool { get }
    var permissionMessage: String { get }

    // MARK: Commands
    func reset()
    func startListening()
    func stopListeningAndFinalize() async -> String?
    func markGenerating()
    func markSuccess()
    func markFailure(_ message: String)
}

// MARK: - Conformance
extension OrbEngine: OrbEngineProtocol {}
