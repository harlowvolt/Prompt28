#!/usr/bin/env python3
"""
Fix remaining file paths
"""

import plistlib

# Map filename -> correct path relative to parent group
REMAINING_FILES = {
    # In Features/ group
    'ShareCardFileStore.swift': 'Home/Views/ShareCardFileStore.swift',
    'ShareCardRenderer.swift': 'Home/Views/ShareCardRenderer.swift',
    'ResultView.swift': 'Home/Views/ResultView.swift',
    'HomeView.swift': 'Home/Views/HomeView.swift',
    'UpgradeView.swift': 'Settings/Views/UpgradeView.swift',
    'SettingsViewModel.swift': 'Settings/ViewModels/SettingsViewModel.swift',
    
    # In App/ group  
    'AppRouter.swift': 'Routing/AppRouter.swift',
    
    # In Core/ group
    'UsageTracker.swift': 'Store/UsageTracker.swift',
    'StoreManager.swift': 'Store/StoreManager.swift',
    'StorageProtocols.swift': 'Protocols/StorageProtocols.swift',
    'APIClientProtocol.swift': 'Protocols/APIClientProtocol.swift',
    'OrbEngine.swift': 'Audio/OrbEngine.swift',
    'SpeechRecognizerService.swift': 'Audio/SpeechRecognizerService.swift',
    'HistoryStore.swift': 'Storage/HistoryStore.swift',
    'PreferencesStore.swift': 'Storage/PreferencesStore.swift',
    'Date+Extensions.swift': 'Utils/Date+Extensions.swift',
    'BundleCatalogLoader.swift': 'Utils/BundleCatalogLoader.swift',
    'HapticService.swift': 'Utils/HapticService.swift',
    'TelemetryService.swift': 'Utils/TelemetryService.swift',
    'NetworkError.swift': 'Networking/NetworkError.swift',
    'APIEndpoint.swift': 'Networking/APIEndpoint.swift',
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
            if path in REMAINING_FILES:
                new_path = REMAINING_FILES[path]
                print(f"Fixing: {path} -> {new_path}")
                obj['path'] = new_path
                fixed_count += 1
    
    print(f"\nTotal fixed: {fixed_count}")
    
    with open(pbxproj_path, 'wb') as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
    
    print("Saved project.pbxproj")

if __name__ == "__main__":
    fix_paths()
