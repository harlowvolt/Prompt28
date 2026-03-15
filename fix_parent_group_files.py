#!/usr/bin/env python3
"""
Fix files that are in parent groups but need subdirectory paths
"""

import plistlib

# Files that are in parent groups but need subdirectory prefix
FILES_IN_PARENT_NEEDING_PREFIX = {
    # In Models group but files are in Models/API/
    "PromptCatalogModels.swift": "API/PromptCatalogModels.swift",
    "User.swift": "API/User.swift",
    "SettingsModels.swift": "API/SettingsModels.swift",
    # In Models group but files are in Models/Local/
    "AppPreferences.swift": "Local/AppPreferences.swift",
    # In Features group but files are in Features/Onboarding/Views/
    "OnboardingView.swift": "Onboarding/Views/OnboardingView.swift",
    # In Features group but files are in Features/Trending/Views/ (PromptDetailView)
    "PromptDetailView.swift": "Trending/Views/PromptDetailView.swift",
    # In Features group but files are in Features/History/Views/
    "HistoryView.swift": "History/Views/HistoryView.swift",
    # In Features group but files are in Features/Admin/Views/
    "AdminPromptsView.swift": "Admin/Views/AdminPromptsView.swift",
    "AdminTextSettingsView.swift": "Admin/Views/AdminTextSettingsView.swift",
    "AdminUnlockView.swift": "Admin/Views/AdminUnlockView.swift",
    "AdminDashboardView.swift": "Admin/Views/AdminDashboardView.swift",
    "AdminCategoriesView.swift": "Admin/Views/AdminCategoriesView.swift",
    # In Features group but files are in Features/Admin/ViewModels/
    "AdminViewModel.swift": "Admin/ViewModels/AdminViewModel.swift",
    # In Features group but files are in Features/Auth/Views/
    "AuthFlowView.swift": "Auth/Views/AuthFlowView.swift",
    "EmailAuthView.swift": "Auth/Views/EmailAuthView.swift",
    # In Features group but files are in Features/Auth/ViewModels/
    "AuthViewModel.swift": "Auth/ViewModels/AuthViewModel.swift",
    # In Features group but files are in Features/Privacy/
    "PrivacyConsentView.swift": "Privacy/PrivacyConsentView.swift",
    # In Features group but files are in Features/Home/Views/
    "ShareCardView.swift": "Home/Views/ShareCardView.swift",
    "OrbView.swift": "Home/Views/OrbView.swift",
    "TypePromptView.swift": "Home/Views/TypePromptView.swift",
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
            
            if filename in FILES_IN_PARENT_NEEDING_PREFIX:
                new_path = FILES_IN_PARENT_NEEDING_PREFIX[filename]
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
