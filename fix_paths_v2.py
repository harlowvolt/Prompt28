#!/usr/bin/env python3
"""
Fix file paths - files in subgroups should only have filenames
Files directly in parent groups should have subdirectory prefixes
"""

import plistlib

# For files in subgroups (like Core/Auth/), the path should just be the filename
# For files directly in parent groups (like Core/), the path should include subdirectory

# Files that are in subgroups and should only have filename as path
FILES_IN_SUBGROUPS = {
    # In Core/Auth/
    "KeychainService.swift": "KeychainService.swift",
    "OAuthCoordinator.swift": "OAuthCoordinator.swift",
    # In Core/Storage/
    "SecureStore.swift": "SecureStore.swift",
    "CloudKitService.swift": "CloudKitService.swift",
    "PreferencesStore.swift": "PreferencesStore.swift",
    "HistoryStore.swift": "HistoryStore.swift",
    # In Core/Utils/
    "JSONCoding.swift": "JSONCoding.swift",
    "AnalyticsService.swift": "AnalyticsService.swift",
    "TelemetryService.swift": "TelemetryService.swift",
    "HapticService.swift": "HapticService.swift",
    "BundleCatalogLoader.swift": "BundleCatalogLoader.swift",
    "Date+Extensions.swift": "Date+Extensions.swift",
    # In Core/Store/
    "StoreConfig.swift": "StoreConfig.swift",
    "StoreManager.swift": "StoreManager.swift",
    "UsageTracker.swift": "UsageTracker.swift",
    # In Core/Notifications/
    "NotificationService.swift": "NotificationService.swift",
    # In Core/Audio/
    "SpeechRecognizerService.swift": "SpeechRecognizerService.swift",
    "OrbEngine.swift": "OrbEngine.swift",
    # In Core/Protocols/
    "APIClientProtocol.swift": "APIClientProtocol.swift",
    "StorageProtocols.swift": "StorageProtocols.swift",
    # In Core/Networking/ - these are currently directly in Core but need to be in Networking
    # Actually let's check - they're showing as direct children with Networking/ prefix
    # So they should stay as Networking/APIClient.swift etc.
}

# Files that need to be moved to subgroups and need full path
# These are currently direct children of Core/Features but should include subgroup prefix
FILES_NEEDING_SUBGROUP_PATH = {
    "AuthManager.swift": "Auth/AuthManager.swift",
    "APIClient.swift": "Networking/APIClient.swift",
    "RequestBuilder.swift": "Networking/RequestBuilder.swift",
    "APIEndpoint.swift": "Networking/APIEndpoint.swift",
    "NetworkError.swift": "Networking/NetworkError.swift",
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
            # Strip any directory prefix to get filename
            filename = path.split('/')[-1] if '/' in path else path
            
            if filename in FILES_IN_SUBGROUPS:
                new_path = FILES_IN_SUBGROUPS[filename]
                if path != new_path:
                    print(f"Fixing (subgroup): {path} -> {new_path}")
                    obj['path'] = new_path
                    fixed_count += 1
            elif filename in FILES_NEEDING_SUBGROUP_PATH:
                new_path = FILES_NEEDING_SUBGROUP_PATH[filename]
                if path != new_path:
                    print(f"Fixing (add prefix): {path} -> {new_path}")
                    obj['path'] = new_path
                    fixed_count += 1
    
    print(f"\nTotal fixed: {fixed_count}")
    
    with open(pbxproj_path, 'wb') as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
    
    print("Saved project.pbxproj")

if __name__ == "__main__":
    fix_paths()
