#!/usr/bin/env python3
"""
Fix file paths that need subdirectory prefixes
"""

import plistlib

# Files that need their paths updated to include subdirectories
# relative to their parent group
FILES_NEEDING_SUBDIR_PATHS = {
    # In Features/ group - need relative paths from Features group
    'OnboardingView.swift': 'Onboarding/Views/OnboardingView.swift',
    'PromptDetailView.swift': 'PromptSelection/Views/PromptDetailView.swift',
    'HistoryView.swift': 'History/Views/HistoryView.swift',
    'AdminPromptsView.swift': 'Admin/Views/AdminPromptsView.swift',
    'AdminTextSettingsView.swift': 'Admin/Views/AdminTextSettingsView.swift',
    'AdminUnlockView.swift': 'Admin/Views/AdminUnlockView.swift',
    'AdminDashboardView.swift': 'Admin/Views/AdminDashboardView.swift',
    'AdminCategoriesView.swift': 'Admin/Views/AdminCategoriesView.swift',
    'AdminViewModel.swift': 'Admin/ViewModels/AdminViewModel.swift',
    'AuthFlowView.swift': 'Authentication/Views/AuthFlowView.swift',
    'EmailAuthView.swift': 'Authentication/Views/EmailAuthView.swift',
    'PrivacyConsentView.swift': 'Privacy/Views/PrivacyConsentView.swift',
    'ShareCardView.swift': 'Home/Views/ShareCardView.swift',
    'OrbView.swift': 'Home/Views/OrbView.swift',
    'TypePromptView.swift': 'Home/Views/TypePromptView.swift',
    'GenerateViewModel.swift': 'Home/ViewModels/GenerateViewModel.swift',
    'AuthViewModel.swift': 'Authentication/ViewModels/AuthViewModel.swift',
    # In Models/ group - need relative paths from Models group  
    'PromptCatalogModels.swift': 'API/PromptCatalogModels.swift',
    'User.swift': 'API/User.swift',
    'SettingsModels.swift': 'API/SettingsModels.swift',
    'AppPreferences.swift': 'Local/AppPreferences.swift',
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
            if path in FILES_NEEDING_SUBDIR_PATHS:
                new_path = FILES_NEEDING_SUBDIR_PATHS[path]
                print(f"Fixing: {path} -> {new_path}")
                obj['path'] = new_path
                fixed_count += 1
    
    print(f"\nTotal fixed: {fixed_count}")
    
    with open(pbxproj_path, 'wb') as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
    
    print("Saved project.pbxproj")

if __name__ == "__main__":
    fix_paths()
