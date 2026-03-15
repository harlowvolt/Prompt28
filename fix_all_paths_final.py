#!/usr/bin/env python3
"""
Final comprehensive fix for all file paths
Paths are relative to their immediate parent group
"""

import plistlib

# Correct paths relative to their parent groups
# Key: filename, Value: correct path relative to immediate parent group
CORRECT_PATHS = {
    # Core/Audio/
    "SpeechRecognizerService.swift": "Audio/SpeechRecognizerService.swift",
    "OrbEngine.swift": "Audio/OrbEngine.swift",
    
    # Core/Auth/
    "KeychainService.swift": "Auth/KeychainService.swift",
    "OAuthCoordinator.swift": "Auth/OAuthCoordinator.swift",
    "AuthManager.swift": "Auth/AuthManager.swift",
    
    # Core/Networking/
    "APIClient.swift": "Networking/APIClient.swift",
    "RequestBuilder.swift": "Networking/RequestBuilder.swift",
    "APIEndpoint.swift": "Networking/APIEndpoint.swift",
    "NetworkError.swift": "Networking/NetworkError.swift",
    
    # Core/Protocols/
    "APIClientProtocol.swift": "Protocols/APIClientProtocol.swift",
    "StorageProtocols.swift": "Protocols/StorageProtocols.swift",
    
    # Core/Services/ (none seem to need fixing based on earlier output)
    
    # Core/Storage/
    "SecureStore.swift": "Storage/SecureStore.swift",
    "PreferencesStore.swift": "Storage/PreferencesStore.swift",
    "HistoryStore.swift": "Storage/HistoryStore.swift",
    "CloudKitService.swift": "Storage/CloudKitService.swift",
    
    # Core/Store/
    "StoreConfig.swift": "Store/StoreConfig.swift",
    "StoreManager.swift": "Store/StoreManager.swift",
    "UsageTracker.swift": "Store/UsageTracker.swift",
    
    # Core/Utils/
    "BundleCatalogLoader.swift": "Utils/BundleCatalogLoader.swift",
    "HapticService.swift": "Utils/HapticService.swift",
    "AnalyticsService.swift": "Utils/AnalyticsService.swift",
    "TelemetryService.swift": "Utils/TelemetryService.swift",
    "Date+Extensions.swift": "Utils/Date+Extensions.swift",
    "JSONCoding.swift": "Utils/JSONCoding.swift",
    
    # Core/Notifications/
    "NotificationService.swift": "Notifications/NotificationService.swift",
    
    # App/
    "OrionMainContainer.swift": "OrionMainContainer.swift",
    "AppEnvironment.swift": "AppEnvironment.swift",
    "RootView.swift": "RootView.swift",
    "PremiumTabScreen.swift": "PremiumTabScreen.swift",
    "AppUI.swift": "AppUI.swift",
    "PromptMeNativeApp.swift": "PromptMeNativeApp.swift",
    
    # App/Routing/
    "AppRouter.swift": "Routing/AppRouter.swift",
    
    # Features/Admin/Views/
    "AdminPromptsView.swift": "Admin/Views/AdminPromptsView.swift",
    "AdminPromptEditorSheet.swift": "Admin/Views/AdminPromptEditorSheet.swift",
    "AdminUnlockView.swift": "Admin/Views/AdminUnlockView.swift",
    "AdminCategoriesView.swift": "Admin/Views/AdminCategoriesView.swift",
    "AdminDashboardView.swift": "Admin/Views/AdminDashboardView.swift",
    "AdminTextSettingsView.swift": "Admin/Views/AdminTextSettingsView.swift",
    
    # Features/Admin/ViewModels/
    "AdminViewModel.swift": "Admin/ViewModels/AdminViewModel.swift",
    
    # Features/Auth/Views/ (actually Authentication in my earlier scripts)
    "AuthFlowView.swift": "Auth/Views/AuthFlowView.swift",
    "EmailAuthView.swift": "Auth/Views/EmailAuthView.swift",
    
    # Features/Auth/ViewModels/
    "AuthViewModel.swift": "Auth/ViewModels/AuthViewModel.swift",
    
    # Features/History/Views/
    "HistoryView.swift": "History/Views/HistoryView.swift",
    "FavoritesView.swift": "History/Views/FavoritesView.swift",
    
    # Features/History/ViewModels/
    "HistoryViewModel.swift": "History/ViewModels/HistoryViewModel.swift",
    
    # Features/Home/Views/
    "HomeView.swift": "Home/Views/HomeView.swift",
    "ResultView.swift": "Home/Views/ResultView.swift",
    "ShareCardRenderer.swift": "Home/Views/ShareCardRenderer.swift",
    "ShareCardFileStore.swift": "Home/Views/ShareCardFileStore.swift",
    "TypePromptView.swift": "Home/Views/TypePromptView.swift",
    "OrbView.swift": "Home/Views/OrbView.swift",
    "ShareCardView.swift": "Home/Views/ShareCardView.swift",
    
    # Features/Home/ViewModels/
    "HomeViewModel.swift": "Home/ViewModels/HomeViewModel.swift",
    "GenerateViewModel.swift": "Home/ViewModels/GenerateViewModel.swift",
    
    # Features/Onboarding/Views/
    "OnboardingView.swift": "Onboarding/Views/OnboardingView.swift",
    
    # Features/Privacy/
    "PrivacyConsentView.swift": "Privacy/PrivacyConsentView.swift",
    
    # Features/Settings/Views/
    "SettingsView.swift": "Settings/Views/SettingsView.swift",
    "UpgradeView.swift": "Settings/Views/UpgradeView.swift",
    
    # Features/Settings/ViewModels/
    "SettingsViewModel.swift": "Settings/ViewModels/SettingsViewModel.swift",
    
    # Features/Trending/Views/
    "TrendingView.swift": "Trending/Views/TrendingView.swift",
    "PromptDetailView.swift": "Trending/Views/PromptDetailView.swift",
    
    # Features/Trending/ViewModels/
    "TrendingViewModel.swift": "Trending/ViewModels/TrendingViewModel.swift",
    
    # Models/API/
    "PromptCatalogModels.swift": "API/PromptCatalogModels.swift",
    "User.swift": "API/User.swift",
    "SettingsModels.swift": "API/SettingsModels.swift",
    "AuthModels.swift": "API/AuthModels.swift",
    "GenerateModels.swift": "API/GenerateModels.swift",
    
    # Models/Local/
    "PromptHistoryItem.swift": "Local/PromptHistoryItem.swift",
    "AppPreferences.swift": "Local/AppPreferences.swift",
}

def fix_paths():
    pbxproj_path = "Prompt28.xcodeproj/project.pbxproj"
    
    with open(pbxproj_path, 'rb') as f:
        plist = plistlib.load(f)
    
    objects = plist['objects']
    fixed_count = 0
    
    for key, obj in objects.items():
        if obj.get('isa') == 'PBXFileReference':
            path = obj.get('path', '')
            if path in CORRECT_PATHS:
                new_path = CORRECT_PATHS[path]
                if path != new_path:
                    print(f"Fixing: {path} -> {new_path}")
                    obj['path'] = new_path
                    fixed_count += 1
    
    print(f"\nTotal fixed: {fixed_count}")
    
    with open(pbxproj_path, 'wb') as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
    
    print("Saved project.pbxproj")

if __name__ == "__main__":
    fix_paths()
