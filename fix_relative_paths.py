#!/usr/bin/env python3
"""
Fix file paths in project.pbxproj to be relative to their parent groups
"""

import plistlib
import os

# Mapping from filename to correct path relative to its immediate parent group
# We need to understand the group hierarchy:
# PromptMeNative_Blueprint/
#   Core/
#     Auth/ -> files here should have path relative to Auth (just filename)
#     Audio/ -> files here should have path relative to Audio
#     Networking/ -> etc.
#   Features/
#     Admin/Views/ -> files here should have path relative to Views
#   Models/
#     API/ -> files here should have path relative to API
#     Local/ -> files here should have path relative to Local

# First let's map all files to their correct paths relative to the group they're in
FILE_TO_RELATIVE_PATH = {
    # Files in Features/Admin/Views/
    "AdminPromptsView.swift": "AdminPromptsView.swift",  # In Features/Admin/Views group
    "AdminUnlockView.swift": "AdminUnlockView.swift",
    "AdminCategoriesView.swift": "AdminCategoriesView.swift",
    
    # Files in Features/Home/Views/
    "OrbView.swift": "OrbView.swift",
    "ShareCardView.swift": "ShareCardView.swift",
    
    # Files in Features/Authentication/Views/
    "AuthFlowView.swift": "AuthFlowView.swift",
    "EmailAuthView.swift": "EmailAuthView.swift",
    
    # Files in Features/
    "TypePromptView.swift": "TypePromptView.swift",
    "GenerateViewModel.swift": "GenerateViewModel.swift",
    
    # Files in Features/ShareCard/
    "ShareCardFileStore.swift": "ShareCardFileStore.swift",
    "ShareCardRenderer.swift": "ShareCardRenderer.swift",
    
    # Files in Features/Admin/ViewModels/
    "AdminViewModel.swift": "AdminViewModel.swift",
    
    # Files directly in Core/Auth/ (relative to Auth group, so just filename)
    "KeychainService.swift": "KeychainService.swift",
    "OAuthCoordinator.swift": "OAuthCoordinator.swift",
    "AuthManager.swift": "AuthManager.swift",
    
    # Files in Core/Audio/
    "SpeechRecognizerService.swift": "SpeechRecognizerService.swift",
    "OrbEngine.swift": "OrbEngine.swift",
    "AudioSessionManager.swift": "AudioSessionManager.swift",
    
    # Files in Core/Networking/
    "APIClient.swift": "APIClient.swift",
    "RequestBuilder.swift": "RequestBuilder.swift",
    "APIEndpoint.swift": "APIEndpoint.swift",
    "NetworkError.swift": "NetworkError.swift",
    
    # Files in Core/Protocols/
    "APIClientProtocol.swift": "APIClientProtocol.swift",
    
    # Files in Core/Services/
    "PromptService.swift": "PromptService.swift",
    "ErrorService.swift": "ErrorService.swift",
    "CatalogSyncService.swift": "CatalogSyncService.swift",
    "OnboardingService.swift": "OnboardingService.swift",
    
    # Files in Core/Storage/
    "SecureStore.swift": "SecureStore.swift",
    "PreferencesStore.swift": "PreferencesStore.swift",
    "HistoryStore.swift": "HistoryStore.swift",
    "CloudKitService.swift": "CloudKitService.swift",
    
    # Files in Core/Utils/
    "BundleCatalogLoader.swift": "BundleCatalogLoader.swift",
    "HapticService.swift": "HapticService.swift",
    "AnalyticsService.swift": "AnalyticsService.swift",
    "TelemetryService.swift": "TelemetryService.swift",
    "Date+Extensions.swift": "Date+Extensions.swift",
    "JSONCoding.swift": "JSONCoding.swift",
    
    # Files in Core/Extensions/
    "AppPreferences+Defaults.swift": "AppPreferences+Defaults.swift",
    
    # Files in Features/Authentication/ViewModels/
    "AuthViewModel.swift": "AuthViewModel.swift",
    
    # Files in Features/Home/Views/
    "HomeView.swift": "HomeView.swift",
    "PlusButton.swift": "PlusButton.swift",
    
    # Files in Features/Input/Views/
    "InputView.swift": "InputView.swift",
    "InputConfirmationDialog.swift": "InputConfirmationDialog.swift",
    
    # Files in Features/Input/ViewModels/
    "InputViewModel.swift": "InputViewModel.swift",
    
    # Files in Features/Onboarding/Views/
    "OnboardingView.swift": "OnboardingView.swift",
    "OnboardingPageView.swift": "OnboardingPageView.swift",
    "ContextualOnboardingOverlay.swift": "ContextualOnboardingOverlay.swift",
    
    # Files in Features/Onboarding/ViewModels/
    "OnboardingViewModel.swift": "OnboardingViewModel.swift",
    
    # Files in Features/Privacy/Views/
    "PrivacyGateView.swift": "PrivacyGateView.swift",
    "PrivacyConsentView.swift": "PrivacyConsentView.swift",
    
    # Files in Features/PromptSelection/Views/
    "PromptSelectionView.swift": "PromptSelectionView.swift",
    "PromptCardView.swift": "PromptCardView.swift",
    "PromptDetailView.swift": "PromptDetailView.swift",
    
    # Files in Features/PromptSelection/ViewModels/
    "PromptSelectionViewModel.swift": "PromptSelectionViewModel.swift",
    
    # Files in Features/Result/Views/
    "ResultView.swift": "ResultView.swift",
    
    # Files in Features/Result/ViewModels/
    "ResultViewModel.swift": "ResultViewModel.swift",
    
    # Files in Features/History/Views/
    "HistoryListView.swift": "HistoryListView.swift",
    "HistoryCardView.swift": "HistoryCardView.swift",
    "HistoryView.swift": "HistoryView.swift",
    "HistoryDetailView.swift": "HistoryDetailView.swift",
    
    # Files in Features/History/ViewModels/
    "HistoryViewModel.swift": "HistoryViewModel.swift",
    
    # Files in Features/Settings/Views/
    "SettingsView.swift": "SettingsView.swift",
    
    # Files in Features/Settings/ViewModels/
    "SettingsViewModel.swift": "SettingsViewModel.swift",
    
    # Files in Features/Upgrade/Views/
    "UpgradeView.swift": "UpgradeView.swift",
    
    # Files in Features/Upgrade/Services/
    "StoreManager.swift": "StoreManager.swift",
    
    # Files in Features/Upgrade/Models/
    "PremiumTabScreen.swift": "PremiumTabScreen.swift",
    
    # Files in Features/Upgrade/ViewModels/
    "UpgradeViewModel.swift": "UpgradeViewModel.swift",
    
    # Files in Features/Admin/Views/
    "AdminDashboardView.swift": "AdminDashboardView.swift",
    "AdminTextSettingsView.swift": "AdminTextSettingsView.swift",
    
    # Files in Routing/
    "AppRouter.swift": "AppRouter.swift",
    
    # Files in UI/
    "PromptPremiumBackground.swift": "PromptPremiumBackground.swift",
    "OrbButton.swift": "OrbButton.swift",
    "OrbModifier.swift": "OrbModifier.swift",
    "TypewriterText.swift": "TypewriterText.swift",
    "OrbTextField.swift": "OrbTextField.swift",
    "LoadingCard.swift": "LoadingCard.swift",
    "OrbToast.swift": "OrbToast.swift",
    "CopyFeedbackView.swift": "CopyFeedbackView.swift",
    "SwipeAction.swift": "SwipeAction.swift",
    "TouchVisualizer.swift": "TouchVisualizer.swift",
    "BetaBanner.swift": "BetaBanner.swift",
    "KeyboardAdaptive.swift": "KeyboardAdaptive.swift",
    "AnimatedSaveIndicator.swift": "AnimatedSaveIndicator.swift",
    "OrbStyle.swift": "OrbStyle.swift",
    "OrbTextFieldStyle.swift": "OrbTextFieldStyle.swift",
    "ModernFormField.swift": "ModernFormField.swift",
    "ModernTextEditor.swift": "ModernTextEditor.swift",
    "EnhancedCard.swift": "EnhancedCard.swift",
    "SpringyButton.swift": "SpringyButton.swift",
    "AppUI.swift": "AppUI.swift",
    
    # Files in Models/API/
    "PromptCatalogModels.swift": "PromptCatalogModels.swift",
    "User.swift": "User.swift",
    "SettingsModels.swift": "SettingsModels.swift",
    
    # Files in Models/Local/
    "AppPreferences.swift": "AppPreferences.swift",
    "PromptHistoryItem.swift": "PromptHistoryItem.swift",
    "HistoryItem.swift": "HistoryItem.swift",
    "PromptMode.swift": "PromptMode.swift",
    "HistoryFilter.swift": "HistoryFilter.swift",
    "HistoryViewState.swift": "HistoryViewState.swift",
    "InputState.swift": "InputState.swift",
    "InputField.swift": "InputField.swift",
    "OnboardingPhase.swift": "OnboardingPhase.swift",
    "OnboardingStep.swift": "OnboardingStep.swift",
    "AuthError.swift": "AuthError.swift",
    "AuthState.swift": "AuthState.swift",
    "AppError.swift": "AppError.swift",
    "OrbFieldConfiguration.swift": "OrbFieldConfiguration.swift",
    "OrbButtonConfiguration.swift": "OrbButtonConfiguration.swift",
    "Toast.swift": "Toast.swift",
    "OrbAnimationState.swift": "OrbAnimationState.swift",
    "StorageProtocols.swift": "StorageProtocols.swift",
    
    # Files in Usage/
    "UsageTracker.swift": "UsageTracker.swift",
    
    # Files in App/
    "OrionMainContainer.swift": "OrionMainContainer.swift",
    "AppEnvironment.swift": "AppEnvironment.swift",
    "AppState.swift": "AppState.swift",
    "AppPhase.swift": "AppPhase.swift",
    "ScenePhaseObserver.swift": "ScenePhaseObserver.swift",
    "PromptMeNativeApp.swift": "PromptMeNativeApp.swift",
    "AppInitializer.swift": "AppInitializer.swift",
    "RootView.swift": "RootView.swift",
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
                filename = os.path.basename(path)
                if filename in FILE_TO_RELATIVE_PATH:
                    correct_path = FILE_TO_RELATIVE_PATH[filename]
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
