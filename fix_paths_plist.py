#!/usr/bin/env python3
"""
Fix file paths in project.pbxproj using plistlib
"""

import plistlib
import os

# Mapping from filename to correct path relative to source root
FILE_PATH_MAPPING = {
    # App
    "OrionMainContainer.swift": "App/OrionMainContainer.swift",
    "AppEnvironment.swift": "App/AppEnvironment.swift",
    "AppState.swift": "App/AppState.swift",
    "AppPhase.swift": "App/AppPhase.swift",
    "ScenePhaseObserver.swift": "App/ScenePhaseObserver.swift",
    "PromptMeNativeApp.swift": "App/PromptMeNativeApp.swift",
    "AppInitializer.swift": "App/AppInitializer.swift",
    "RootView.swift": "App/RootView.swift",
    
    # Core/Auth
    "AuthManager.swift": "Core/Auth/AuthManager.swift",
    "KeychainService.swift": "Core/Auth/KeychainService.swift",
    "OAuthCoordinator.swift": "Core/Auth/OAuthCoordinator.swift",
    
    # Core/Audio
    "SpeechRecognizerService.swift": "Core/Audio/SpeechRecognizerService.swift",
    "OrbEngine.swift": "Core/Audio/OrbEngine.swift",
    "AudioSessionManager.swift": "Core/Audio/AudioSessionManager.swift",
    
    # Core/Networking
    "APIClient.swift": "Core/Networking/APIClient.swift",
    "RequestBuilder.swift": "Core/Networking/RequestBuilder.swift",
    "APIEndpoint.swift": "Core/Networking/APIEndpoint.swift",
    "NetworkError.swift": "Core/Networking/NetworkError.swift",
    
    # Core/Protocols
    "APIClientProtocol.swift": "Core/Protocols/APIClientProtocol.swift",
    
    # Core/Services
    "PromptService.swift": "Core/Services/PromptService.swift",
    "ErrorService.swift": "Core/Services/ErrorService.swift",
    "CatalogSyncService.swift": "Core/Services/CatalogSyncService.swift",
    "OnboardingService.swift": "Core/Services/OnboardingService.swift",
    
    # Core/Storage
    "SecureStore.swift": "Core/Storage/SecureStore.swift",
    "PreferencesStore.swift": "Core/Storage/PreferencesStore.swift",
    "HistoryStore.swift": "Core/Storage/HistoryStore.swift",
    "CloudKitService.swift": "Core/Storage/CloudKitService.swift",
    
    # Core/Utils
    "BundleCatalogLoader.swift": "Core/Utils/BundleCatalogLoader.swift",
    "HapticService.swift": "Core/Utils/HapticService.swift",
    "AnalyticsService.swift": "Core/Utils/AnalyticsService.swift",
    "TelemetryService.swift": "Core/Utils/TelemetryService.swift",
    "Date+Extensions.swift": "Core/Utils/Date+Extensions.swift",
    "JSONCoding.swift": "Core/Utils/JSONCoding.swift",
    
    # Core/Extensions
    "AppPreferences+Defaults.swift": "Core/Extensions/AppPreferences+Defaults.swift",
    
    # Features/Authentication
    "AuthenticationView.swift": "Features/Authentication/Views/AuthenticationView.swift",
    "AuthViewModel.swift": "Features/Authentication/ViewModels/AuthViewModel.swift",
    
    # Features/Home
    "HomeView.swift": "Features/Home/Views/HomeView.swift",
    "PlusButton.swift": "Features/Home/Views/PlusButton.swift",
    
    # Features/Input
    "InputView.swift": "Features/Input/Views/InputView.swift",
    "InputConfirmationDialog.swift": "Features/Input/Views/InputConfirmationDialog.swift",
    "InputViewModel.swift": "Features/Input/ViewModels/InputViewModel.swift",
    
    # Features/Onboarding
    "OnboardingView.swift": "Features/Onboarding/Views/OnboardingView.swift",
    "OnboardingPageView.swift": "Features/Onboarding/Views/OnboardingPageView.swift",
    "ContextualOnboardingOverlay.swift": "Features/Onboarding/Views/ContextualOnboardingOverlay.swift",
    "OnboardingViewModel.swift": "Features/Onboarding/ViewModels/OnboardingViewModel.swift",
    
    # Features/Privacy
    "PrivacyGateView.swift": "Features/Privacy/Views/PrivacyGateView.swift",
    "PrivacyConsentView.swift": "Features/Privacy/Views/PrivacyConsentView.swift",
    
    # Features/PromptSelection
    "PromptSelectionView.swift": "Features/PromptSelection/Views/PromptSelectionView.swift",
    "PromptCardView.swift": "Features/PromptSelection/Views/PromptCardView.swift",
    "PromptDetailView.swift": "Features/PromptSelection/Views/PromptDetailView.swift",
    "PromptSelectionViewModel.swift": "Features/PromptSelection/ViewModels/PromptSelectionViewModel.swift",
    
    # Features/Result
    "ResultView.swift": "Features/Result/Views/ResultView.swift",
    "ResultViewModel.swift": "Features/Result/ViewModels/ResultViewModel.swift",
    
    # Features/History
    "HistoryListView.swift": "Features/History/Views/HistoryListView.swift",
    "HistoryCardView.swift": "Features/History/Views/HistoryCardView.swift",
    "HistoryView.swift": "Features/History/Views/HistoryView.swift",
    "HistoryViewModel.swift": "Features/History/ViewModels/HistoryViewModel.swift",
    "HistoryDetailView.swift": "Features/History/Views/HistoryDetailView.swift",
    
    # Features/Settings
    "SettingsView.swift": "Features/Settings/Views/SettingsView.swift",
    "SettingsViewModel.swift": "Features/Settings/ViewModels/SettingsViewModel.swift",
    
    # Features/Upgrade
    "UpgradeView.swift": "Features/Upgrade/Views/UpgradeView.swift",
    "StoreManager.swift": "Features/Upgrade/Services/StoreManager.swift",
    "PremiumTabScreen.swift": "Features/Upgrade/Models/PremiumTabScreen.swift",
    "UpgradeViewModel.swift": "Features/Upgrade/ViewModels/UpgradeViewModel.swift",
    
    # Features/Admin
    "AdminDashboardView.swift": "Features/Admin/Views/AdminDashboardView.swift",
    "AdminTextSettingsView.swift": "Features/Admin/Views/AdminTextSettingsView.swift",
    
    # Routing
    "AppRouter.swift": "Routing/AppRouter.swift",
    
    # UI
    "PromptPremiumBackground.swift": "UI/PromptPremiumBackground.swift",
    "OrbButton.swift": "UI/OrbButton.swift",
    "OrbModifier.swift": "UI/OrbModifier.swift",
    "TypewriterText.swift": "UI/TypewriterText.swift",
    "OrbTextField.swift": "UI/OrbTextField.swift",
    "LoadingCard.swift": "UI/LoadingCard.swift",
    "OrbToast.swift": "UI/OrbToast.swift",
    "CopyFeedbackView.swift": "UI/CopyFeedbackView.swift",
    "SwipeAction.swift": "UI/SwipeAction.swift",
    "TouchVisualizer.swift": "UI/TouchVisualizer.swift",
    "BetaBanner.swift": "UI/BetaBanner.swift",
    "KeyboardAdaptive.swift": "UI/KeyboardAdaptive.swift",
    "AnimatedSaveIndicator.swift": "UI/AnimatedSaveIndicator.swift",
    "OrbStyle.swift": "UI/OrbStyle.swift",
    "OrbTextFieldStyle.swift": "UI/OrbTextFieldStyle.swift",
    "ModernFormField.swift": "UI/ModernFormField.swift",
    "ModernTextEditor.swift": "UI/ModernTextEditor.swift",
    "EnhancedCard.swift": "UI/EnhancedCard.swift",
    "SpringyButton.swift": "UI/SpringyButton.swift",
    "AppUI.swift": "UI/AppUI.swift",
    
    # Models/API
    "PromptCatalogModels.swift": "Models/API/PromptCatalogModels.swift",
    "User.swift": "Models/API/User.swift",
    "SettingsModels.swift": "Models/API/SettingsModels.swift",
    
    # Models/Local
    "AppPreferences.swift": "Models/Local/AppPreferences.swift",
    "PromptHistoryItem.swift": "Models/Local/PromptHistoryItem.swift",
    "HistoryItem.swift": "Models/Local/HistoryItem.swift",
    "PromptMode.swift": "Models/Local/PromptMode.swift",
    "HistoryFilter.swift": "Models/Local/HistoryFilter.swift",
    "HistoryViewState.swift": "Models/Local/HistoryViewState.swift",
    "InputState.swift": "Models/Local/InputState.swift",
    "InputField.swift": "Models/Local/InputField.swift",
    "OnboardingPhase.swift": "Models/Local/OnboardingPhase.swift",
    "OnboardingStep.swift": "Models/Local/OnboardingStep.swift",
    "AuthError.swift": "Models/Local/AuthError.swift",
    "AuthState.swift": "Models/Local/AuthState.swift",
    "AppError.swift": "Models/Local/AppError.swift",
    "OrbFieldConfiguration.swift": "Models/Local/OrbFieldConfiguration.swift",
    "OrbButtonConfiguration.swift": "Models/Local/OrbButtonConfiguration.swift",
    "Toast.swift": "Models/Local/Toast.swift",
    "OrbAnimationState.swift": "Models/Local/OrbAnimationState.swift",
    "StorageProtocols.swift": "Models/Local/StorageProtocols.swift",
    
    # Usage
    "UsageTracker.swift": "Usage/UsageTracker.swift",
}

def fix_paths():
    pbxproj_path = "Prompt28.xcodeproj/project.pbxproj"
    
    # Load the plist
    with open(pbxproj_path, 'rb') as f:
        plist = plistlib.load(f)
    
    objects = plist['objects']
    fixed_count = 0
    
    for key, obj in objects.items():
        if obj.get('isa') == 'PBXFileReference':
            path = obj.get('path', '')
            if path and path.endswith('.swift'):
                # Get the filename from path
                filename = os.path.basename(path)
                if filename in FILE_PATH_MAPPING:
                    correct_path = FILE_PATH_MAPPING[filename]
                    if path != correct_path:
                        print(f"Fixing: {path} -> {correct_path}")
                        obj['path'] = correct_path
                        fixed_count += 1
    
    print(f"\nTotal fixed: {fixed_count}")
    
    # Save back as binary plist
    with open(pbxproj_path, 'wb') as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
    
    print("Saved project.pbxproj")

if __name__ == "__main__":
    fix_paths()
