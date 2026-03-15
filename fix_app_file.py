#!/usr/bin/env python3
"""
Fix PromptMeNativeApp.swift - add to correct group
"""

import plistlib

pbxproj_path = "Prompt28.xcodeproj/project.pbxproj"

with open(pbxproj_path, 'rb') as f:
    plist = plistlib.load(f)

objects = plist['objects']
file_key = '31C7E4FC66AE49F18F094478EB3CB8FB'

# Find PromptMeNative_Blueprint group
for key, obj in objects.items():
    if obj.get('isa') == 'PBXGroup' and obj.get('path') == 'PromptMeNative_Blueprint':
        print(f'Found PromptMeNative_Blueprint group: {key}')
        
        # Check if file is already in group
        if file_key not in obj.get('children', []):
            print(f'Adding {file_key} to group')
            obj['children'].append(file_key)
        else:
            print(f'File {file_key} already in group')
        
        # Fix the file path - it should just be the filename since it's in PromptMeNative_Blueprint group
        file_obj = objects.get(file_key)
        if file_obj:
            old_path = file_obj.get('path', '')
            new_path = 'PromptMeNativeApp.swift'
            if old_path != new_path:
                print(f'Fixing path: {old_path} -> {new_path}')
                file_obj['path'] = new_path
        break

with open(pbxproj_path, 'wb') as f:
    plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)

print("Saved project.pbxproj")
