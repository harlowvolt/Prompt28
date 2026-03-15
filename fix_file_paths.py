#!/usr/bin/env python3
"""
Fix file paths in project.pbxproj to match actual directory structure
"""

import re

# Path corrections: (old_path, new_path)
PATH_CORRECTIONS = [
    # Models -> Models/API/
    ("Models/PromptCatalogModels.swift", "Models/API/PromptCatalogModels.swift"),
    ("Models/User.swift", "Models/API/User.swift"),
    ("Models/SettingsModels.swift", "Models/API/SettingsModels.swift"),
    # Models -> Models/Local/
    ("Models/AppPreferences.swift", "Models/Local/AppPreferences.swift"),
]

# Additional files in wrong locations that need subdirectory fixes
FILES_IN_SUBDIRS = {
    # Features files - check actual locations
    "Features/OnboardingView.swift": "Features/Onboarding/Views/OnboardingView.swift",
    "Features/OnboardingPageView.swift": "Features/Onboarding/Views/OnboardingPageView.swift",
    "Features/PromptSelectionView.swift": "Features/PromptSelection/Views/PromptSelectionView.swift",
    "Features/PromptCardView.swift": "Features/PromptSelection/Views/PromptCardView.swift",
    "Features/HistoryListView.swift": "Features/History/Views/HistoryListView.swift",
    "Features/HistoryCardView.swift": "Features/History/Views/HistoryCardView.swift",
    "Features/InputView.swift": "Features/Input/Views/InputView.swift",
    "Features/InputConfirmationDialog.swift": "Features/Input/Views/InputConfirmationDialog.swift",
    "Features/ResultView.swift": "Features/Result/Views/ResultView.swift",
    "Features/PrivacyGateView.swift": "Features/Privacy/Views/PrivacyGateView.swift",
    "Features/SettingsView.swift": "Features/Settings/Views/SettingsView.swift",
    "Features/AuthenticationView.swift": "Features/Authentication/Views/AuthenticationView.swift",
    "Features/HomeView.swift": "Features/Home/Views/HomeView.swift",
    "Features/PlusButton.swift": "Features/Home/Views/PlusButton.swift",
    "Features/ContextualOnboardingOverlay.swift": "Features/Onboarding/Views/ContextualOnboardingOverlay.swift",
    # UI Components
    "UI/PromptPremiumBackground.swift": "UI/PremiumBackground/PromptPremiumBackground.swift",
    "UI/OrbButton.swift": "UI/OrbButton/OrbButton.swift",
    "UI/OrbModifier.swift": "UI/OrbModifier/OrbModifier.swift",
    "UI/TypewriterText.swift": "UI/TypewriterText/TypewriterText.swift",
    "UI/OrbTextField.swift": "UI/OrbTextField/OrbTextField.swift",
    "UI/LoadingCard.swift": "UI/LoadingCard/LoadingCard.swift",
    "UI/OrbToast.swift": "UI/OrbToast/OrbToast.swift",
    "UI/CopyFeedbackView.swift": "UI/CopyFeedback/CopyFeedbackView.swift",
    "UI/SwipeAction.swift": "UI/SwipeAction/SwipeAction.swift",
    "UI/TouchVisualizer.swift": "UI/TouchVisualizer/TouchVisualizer.swift",
    "UI/BetaBanner.swift": "UI/BetaBanner/BetaBanner.swift",
    "UI/KeyboardAdaptive.swift": "UI/KeyboardAdaptive/KeyboardAdaptive.swift",
    "UI/AnimatedSaveIndicator.swift": "UI/AnimatedSaveIndicator/AnimatedSaveIndicator.swift",
    "UI/OrbStyle.swift": "UI/OrbStyle/OrbStyle.swift",
    "UI/OrbTextFieldStyle.swift": "UI/OrbTextFieldStyle/OrbTextFieldStyle.swift",
    "UI/ModernFormField.swift": "UI/ModernFormField/ModernFormField.swift",
    "UI/ModernTextEditor.swift": "UI/ModernTextEditor/ModernTextEditor.swift",
    "UI/EnhancedCard.swift": "UI/EnhancedCard/EnhancedCard.swift",
    "UI/SpringyButton.swift": "UI/SpringyButton/SpringyButton.swift",
    # App files
    "App/RootView.swift": "App/RootView/RootView.swift",
    "App/AppEnvironment.swift": "App/AppEnvironment/AppEnvironment.swift",
    "App/AppState.swift": "App/AppState/AppState.swift",
    "App/AppPhase.swift": "App/AppPhase/AppPhase.swift",
    "App/ScenePhaseObserver.swift": "App/ScenePhaseObserver/ScenePhaseObserver.swift",
    "App/PromptMeApp.swift": "App/PromptMeApp/PromptMeApp.swift",
    "App/AppInitializer.swift": "App/AppInitializer/AppInitializer.swift",
    "App/OrionMainContainer.swift": "App/OrionMainContainer/OrionMainContainer.swift",
    # Core files
    "Core/SpeechRecognizerService.swift": "Core/Audio/SpeechRecognizerService.swift",
    "Core/OrbEngine.swift": "Core/Audio/OrbEngine.swift",
    "Core/AudioSessionManager.swift": "Core/Audio/AudioSessionManager.swift",
    "Core/KeychainService.swift": "Core/Auth/KeychainService.swift",
    "Core/OAuthCoordinator.swift": "Core/Auth/OAuthCoordinator.swift",
    "Core/AuthManager.swift": "Core/Auth/AuthManager.swift",
    "Core/APIClient.swift": "Core/Networking/APIClient.swift",
    "Core/RequestBuilder.swift": "Core/Networking/RequestBuilder.swift",
    "Core/APIEndpoint.swift": "Core/Networking/APIEndpoint.swift",
    "Core/NetworkError.swift": "Core/Networking/NetworkError.swift",
    "Core/APIClientProtocol.swift": "Core/Protocols/APIClientProtocol.swift",
    "Core/PromptService.swift": "Core/Services/PromptService.swift",
    "Core/ErrorService.swift": "Core/Services/ErrorService.swift",
    "Core/CatalogSyncService.swift": "Core/Services/CatalogSyncService.swift",
    "Core/OnboardingService.swift": "Core/Services/OnboardingService.swift",
    "Core/SecureStore.swift": "Core/Storage/SecureStore.swift",
    "Core/PreferencesStore.swift": "Core/Storage/PreferencesStore.swift",
    "Core/HistoryStore.swift": "Core/Storage/HistoryStore.swift",
    "Core/CloudKitService.swift": "Core/Storage/CloudKitService.swift",
    "Core/BundleCatalogLoader.swift": "Core/Utils/BundleCatalogLoader.swift",
    "Core/HapticService.swift": "Core/Utils/HapticService.swift",
    "Core/AnalyticsService.swift": "Core/Utils/AnalyticsService.swift",
    "Core/TelemetryService.swift": "Core/Utils/TelemetryService.swift",
    "Core/Date+Extensions.swift": "Core/Utils/Date+Extensions.swift",
    "Core/JSONCoding.swift": "Core/Utils/JSONCoding.swift",
    "Core/AppPreferences+Defaults.swift": "Core/Extensions/AppPreferences+Defaults.swift",
    # History models
    "Models/PromptHistoryItem.swift": "Models/Local/PromptHistoryItem.swift",
    "Models/HistoryItem.swift": "Models/Local/HistoryItem.swift",
    "Models/PromptMode.swift": "Models/Local/PromptMode.swift",
    "Models/HistoryFilter.swift": "Models/Local/HistoryFilter.swift",
    "Models/HistoryViewState.swift": "Models/Local/HistoryViewState.swift",
    "Models/InputState.swift": "Models/Local/InputState.swift",
    "Models/InputField.swift": "Models/Local/InputField.swift",
    "Models/OnboardingPhase.swift": "Models/Local/OnboardingPhase.swift",
    "Models/OnboardingStep.swift": "Models/Local/OnboardingStep.swift",
    "Models/AuthError.swift": "Models/Local/AuthError.swift",
    "Models/AuthState.swift": "Models/Local/AuthState.swift",
    "Models/AppError.swift": "Models/Local/AppError.swift",
    "Models/OrbFieldConfiguration.swift": "Models/Local/OrbFieldConfiguration.swift",
    "Models/OrbButtonConfiguration.swift": "Models/Local/OrbButtonConfiguration.swift",
    "Models/Toast.swift": "Models/Local/Toast.swift",
    "Models/OrbAnimationState.swift": "Models/Local/OrbAnimationState.swift",
}

def fix_paths_in_pbxproj():
    pbxproj_path = "Prompt28.xcodeproj/project.pbxproj"
    
    with open(pbxproj_path, 'r') as f:
        content = f.read()
    
    # Count replacements
    replacements = 0
    
    # Fix all the file paths
    for old_path, new_path in FILES_IN_SUBDIRS.items():
        # Look for path = "old_path" or path = old_path;
        old_pattern = f'path = "{old_path}"'
        new_pattern = f'path = "{new_path}"'
        
        if old_pattern in content:
            content = content.replace(old_pattern, new_pattern)
            replacements += 1
            print(f"Fixed: {old_path} -> {new_path}")
        
        # Also try without quotes for some cases
        old_pattern2 = f'path = {old_path};'
        new_pattern2 = f'path = {new_path};'
        
        if old_pattern2 in content:
            content = content.replace(old_pattern2, new_pattern2)
            replacements += 1
            print(f"Fixed: {old_path} -> {new_path}")
    
    print(f"\nTotal path fixes: {replacements}")
    
    with open(pbxproj_path, 'w') as f:
        f.write(content)
    
    return replacements

if __name__ == "__main__":
    fix_paths_in_pbxproj()
