#!/usr/bin/env python3
"""
Fix Models and App group file paths
"""

import plistlib

FILES_TO_FIX = {
    # Models/API/ - files should just have filename
    "AuthModels.swift": "AuthModels.swift",
    "GenerateModels.swift": "GenerateModels.swift",
    "SettingsModels.swift": "SettingsModels.swift",
    "User.swift": "User.swift",
    "PromptCatalogModels.swift": "PromptCatalogModels.swift",
    # Models/Local/
    "PromptHistoryItem.swift": "PromptHistoryItem.swift",
    "AppPreferences.swift": "AppPreferences.swift",
    # App/Routing/
    "AppRouter.swift": "AppRouter.swift",
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
            
            if filename in FILES_TO_FIX:
                new_path = FILES_TO_FIX[filename]
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
