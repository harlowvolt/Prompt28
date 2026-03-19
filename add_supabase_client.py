#!/usr/bin/env python3
"""
Script to add SupabaseClient.swift to the Xcode project.
"""

import plistlib
import uuid
import shutil
import os

def generate_uuid():
    """Generate a UUID in Xcode format (uppercase without dashes)."""
    return str(uuid.uuid4()).upper().replace("-", "")

def add_supabase_client_to_project(project_path, file_path, group_path):
    """Add SupabaseClient.swift to the Xcode project in the Networking group."""
    
    # Read the project file
    with open(project_path, 'rb') as f:
        project = plistlib.load(f)
    
    # Create backup
    backup_path = project_path + '.backup3'
    shutil.copy2(project_path, backup_path)
    print(f"Created backup at {backup_path}")
    
    objects = project['objects']
    
    # Generate IDs for new objects
    file_ref_id = generate_uuid()
    build_file_id = generate_uuid()
    
    # 1. Create PBXFileReference
    file_ref = {
        'isa': 'PBXFileReference',
        'lastKnownFileType': 'sourcecode.swift',
        'path': 'SupabaseClient.swift',
        'sourceTree': '<group>'
    }
    objects[file_ref_id] = file_ref
    print(f"Created file reference: {file_ref_id}")
    
    # 2. Create PBXBuildFile
    build_file = {
        'isa': 'PBXBuildFile',
        'fileRef': file_ref_id
    }
    objects[build_file_id] = build_file
    print(f"Created build file: {build_file_id}")
    
    # 3. Find the Networking group and add the file reference
    networking_group_id = None
    for obj_id, obj in objects.items():
        if obj.get('isa') == 'PBXGroup' and obj.get('path') == 'Networking':
            networking_group_id = obj_id
            if 'children' not in obj:
                obj['children'] = []
            obj['children'].append(file_ref_id)
            print(f"Added to Networking group: {obj_id}")
            break
    
    if not networking_group_id:
        print("Warning: Could not find Networking group, adding to main group instead")
        # Add to main group as fallback
        root_object_id = project['rootObject']
        main_group_id = objects[root_object_id].get('mainGroup')
        if main_group_id and main_group_id in objects:
            objects[main_group_id]['children'].append(file_ref_id)
    
    # 4. Find the main target's sources build phase and add the build file
    for obj_id, obj in objects.items():
        if obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'OrionOrb':
            # Find the sources build phase
            build_phases = obj.get('buildPhases', [])
            for phase_id in build_phases:
                if phase_id in objects and objects[phase_id].get('isa') == 'PBXSourcesBuildPhase':
                    if 'files' not in objects[phase_id]:
                        objects[phase_id]['files'] = []
                    objects[phase_id]['files'].append(build_file_id)
                    print(f"Added to sources build phase: {phase_id}")
                    break
            break
    
    # Write the modified project back
    with open(project_path, 'wb') as f:
        plistlib.dump(project, f)
    
    print("Successfully added SupabaseClient.swift to the project!")
    return True

if __name__ == '__main__':
    project_path = '/Users/nataliewhipps/Desktop/Prompt28/Prompt28.xcodeproj/project.pbxproj'
    
    if not os.path.exists(project_path):
        print(f"Error: Project file not found at {project_path}")
        exit(1)
    
    try:
        add_supabase_client_to_project(
            project_path,
            'PromptMeNative_Blueprint/Core/Networking/SupabaseClient.swift',
            'Networking'
        )
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        exit(1)
