#!/usr/bin/env python3
"""
Add files to Xcode project with "Create groups" option
"""

import plistlib
import uuid

def generate_uuid():
    return str(uuid.uuid4()).upper().replace('-', '')[:24]

# Files to add: (relative_path, parent_group_path)
FILES_TO_ADD = [
    ("App/OrionMainContainer.swift", "App"),
    ("Components/Glassmorphism.swift", "PromptMeNative_Blueprint"),  # New group
    ("Features/Home/Views/OrionHomeView.swift", "Features/Home/Views"),
    ("Features/Settings/Views/OrionSettingsView.swift", "Features/Settings/Views"),
]

def add_files():
    pbxproj_path = "Prompt28.xcodeproj/project.pbxproj"
    
    with open(pbxproj_path, 'rb') as f:
        plist = plistlib.load(f)
    
    objects = plist['objects']
    
    # Find the main target and sources build phase
    target_key = None
    sources_build_phase_key = None
    
    for key, obj in objects.items():
        if obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'OrionOrb':
            target_key = key
            # Find sources build phase
            for build_phase_key in obj.get('buildPhases', []):
                bp = objects.get(build_phase_key)
                if bp and bp.get('isa') == 'PBXSourcesBuildPhase':
                    sources_build_phase_key = build_phase_key
                    break
            break
    
    print(f"Target: {target_key}")
    print(f"Sources Build Phase: {sources_build_phase_key}")
    
    # Find groups
    def find_group_by_path(path_parts, objects):
        """Find a group by its path components"""
        if not path_parts:
            return None
        
        # Start from PromptMeNative_Blueprint
        blueprint_key = None
        for key, obj in objects.items():
            if obj.get('isa') == 'PBXGroup' and obj.get('path') == 'PromptMeNative_Blueprint':
                blueprint_key = key
                break
        
        if not blueprint_key:
            return None
        
        current_key = blueprint_key
        
        for part in path_parts:
            found = False
            current_group = objects.get(current_key)
            if not current_group:
                return None
            
            for child_key in current_group.get('children', []):
                child = objects.get(child_key)
                if child and child.get('isa') == 'PBXGroup':
                    if child.get('path') == part or child.get('name') == part:
                        current_key = child_key
                        found = True
                        break
            
            if not found:
                return None
        
        return current_key
    
    # Process each file
    for file_path, parent_group_path in FILES_TO_ADD:
        filename = file_path.split('/')[-1]
        path_parts = parent_group_path.split('/') if parent_group_path != 'PromptMeNative_Blueprint' else []
        
        # Find or create parent group
        parent_key = find_group_by_path(path_parts, objects)
        
        if not parent_key and parent_group_path == 'PromptMeNative_Blueprint':
            # Use blueprint group directly
            for key, obj in objects.items():
                if obj.get('isa') == 'PBXGroup' and obj.get('path') == 'PromptMeNative_Blueprint':
                    parent_key = key
                    break
        
        if not parent_key:
            print(f"❌ Could not find parent group: {parent_group_path}")
            continue
        
        # Check if file already exists
        parent_group = objects[parent_key]
        file_exists = False
        for child_key in parent_group.get('children', []):
            child = objects.get(child_key)
            if child and child.get('isa') == 'PBXFileReference':
                if child.get('path') == filename or child.get('path') == file_path:
                    print(f"⚠️ File already exists: {filename}")
                    file_exists = True
                    break
        
        if file_exists:
            continue
        
        # Create file reference
        file_ref_key = generate_uuid()
        file_ref = {
            'isa': 'PBXFileReference',
            'lastKnownFileType': 'sourcecode.swift',
            'path': filename,
            'sourceTree': '<group>'
        }
        objects[file_ref_key] = file_ref
        
        # Add to parent group
        if 'children' not in parent_group:
            parent_group['children'] = []
        parent_group['children'].append(file_ref_key)
        
        # Create build file reference
        build_file_key = generate_uuid()
        build_file = {
            'isa': 'PBXBuildFile',
            'fileRef': file_ref_key
        }
        objects[build_file_key] = build_file
        
        # Add to sources build phase
        if sources_build_phase_key:
            sources_phase = objects[sources_build_phase_key]
            if 'files' not in sources_phase:
                sources_phase['files'] = []
            sources_phase['files'].append(build_file_key)
        
        print(f"✅ Added: {file_path} to {parent_group_path}")
    
    # Save
    with open(pbxproj_path, 'wb') as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_BINARY)
    
    print("\nSaved project.pbxproj")

if __name__ == "__main__":
    add_files()
