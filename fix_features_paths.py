#!/usr/bin/env python3
"""
Fix Features group file paths
Files in subgroups should only have filenames
"""

import plistlib

# Files in subgroups that should only have filename
FILES_IN_SUBGROUPS = {
    # Admin/Views/
    "AdminPromptsView.swift": "AdminPromptsView.swift",
    "AdminPromptEditorSheet.swift": "AdminPromptEditorSheet.swift",
    "AdminUnlockView.swift": "AdminUnlockView.swift",
    "AdminCategoriesView.swift": "AdminCategoriesView.swift",
    "AdminDashboardView.swift": "AdminDashboardView.swift",
    "AdminTextSettingsView.swift": "AdminTextSettingsView.swift",
    # Admin/ViewModels/
    "AdminViewModel.swift": "AdminViewModel.swift",
    # History/Views/
    "HistoryView.swift": "HistoryView.swift",
    "FavoritesView.swift": "FavoritesView.swift",
    # History/ViewModels/
    "HistoryViewModel.swift": "HistoryViewModel.swift",
    # Home/Views/
    "HomeView.swift": "HomeView.swift",
    "ResultView.swift": "ResultView.swift",
    "ShareCardRenderer.swift": "ShareCardRenderer.swift",
    "ShareCardFileStore.swift": "ShareCardFileStore.swift",
    "TypePromptView.swift": "TypePromptView.swift",
    "OrbView.swift": "OrbView.swift",
    "ShareCardView.swift": "ShareCardView.swift",
    # Home/ViewModels/
    "HomeViewModel.swift": "HomeViewModel.swift",
    "GenerateViewModel.swift": "GenerateViewModel.swift",
    # Settings/Views/
    "SettingsView.swift": "SettingsView.swift",
    "UpgradeView.swift": "UpgradeView.swift",
    # Settings/ViewModels/
    "SettingsViewModel.swift": "SettingsViewModel.swift",
    # Trending/Views/
    "TrendingView.swift": "TrendingView.swift",
    "PromptDetailView.swift": "PromptDetailView.swift",
    # Trending/ViewModels/
    "TrendingViewModel.swift": "TrendingViewModel.swift",
    # Privacy/
    "PrivacyConsentView.swift": "PrivacyConsentView.swift",
    # Auth/Views/ (Authentication in Xcode)
    "AuthFlowView.swift": "AuthFlowView.swift",
    "EmailAuthView.swift": "EmailAuthView.swift",
    # Auth/ViewModels/
    "AuthViewModel.swift": "AuthViewModel.swift",
    # Onboarding/Views/
    "OnboardingView.swift": "OnboardingView.swift",
    # PromptSelection/Views/
    "PromptDetailView.swift": "PromptDetailView.swift",
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
            filename = path.split('/')[-1] if '/' in path else path
            
            if filename in FILES_IN_SUBGROUPS:
                new_path = FILES_IN_SUBGROUPS[filename]
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
