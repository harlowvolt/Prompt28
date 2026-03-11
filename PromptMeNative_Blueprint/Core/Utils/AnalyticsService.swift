import Foundation

// MARK: - Events

enum AnalyticsEvent {
    case appOpen
    case generateTapped(mode: String)
    case generateSuccess(mode: String, wordCount: Int)
    case generateError(message: String)
    case generateRateLimited
    case copyPrompt
    case sharePrompt
    case favoriteTapped
    case refinePrompt
    case planUpgradeTapped
    case planUpgradeSuccess(plan: String)
    case authSuccess(provider: String)
    case paywallShown
    case onboardingCompleted
    case modeSwitched(to: String)

    var name: String {
        switch self {
        case .appOpen:               return "app_open"
        case .generateTapped:        return "generate_tapped"
        case .generateSuccess:       return "generate_success"
        case .generateError:         return "generate_error"
        case .generateRateLimited:   return "generate_rate_limited"
        case .copyPrompt:            return "copy_prompt"
        case .sharePrompt:           return "share_prompt"
        case .favoriteTapped:        return "favorite_tapped"
        case .refinePrompt:          return "refine_prompt"
        case .planUpgradeTapped:     return "plan_upgrade_tapped"
        case .planUpgradeSuccess:    return "plan_upgrade_success"
        case .authSuccess:           return "auth_success"
        case .paywallShown:          return "paywall_shown"
        case .onboardingCompleted:   return "onboarding_completed"
        case .modeSwitched:          return "mode_switched"
        }
    }

    var properties: [String: Any] {
        switch self {
        case .generateTapped(let mode):
            return ["mode": mode]
        case .generateSuccess(let mode, let wordCount):
            return ["mode": mode, "word_count": wordCount]
        case .generateError(let msg):
            return ["error": msg]
        case .planUpgradeSuccess(let plan):
            return ["plan": plan]
        case .authSuccess(let provider):
            return ["provider": provider]
        case .modeSwitched(let to):
            return ["to": to]
        default:
            return [:]
        }
    }
}

// MARK: - Service

/// Lightweight analytics wrapper. Replace the `track` body with
/// Mixpanel / Amplitude / Firebase when ready — callers stay the same.
final class AnalyticsService {
    static let shared = AnalyticsService()
    private init() {}

    func track(_ event: AnalyticsEvent) {
        #if DEBUG
        let props = event.properties.isEmpty ? "" : " \(event.properties)"
        print("📊 [Analytics] \(event.name)\(props)")
        #endif

        // ── Drop-in replacement examples ──────────────────────────────────
        // Mixpanel:
        //   Mixpanel.mainInstance().track(event: event.name, properties: event.properties)
        // Amplitude:
        //   Amplitude.instance().logEvent(event.name, withEventProperties: event.properties)
        // Firebase:
        //   Analytics.logEvent(event.name, parameters: event.properties)
        // ─────────────────────────────────────────────────────────────────
    }
}
