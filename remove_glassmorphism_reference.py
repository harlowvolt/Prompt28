#!/usr/bin/env python3
"""
Script to remove the Glassmorphism.swift file reference from the Xcode project.
"""

import plistlib
import shutil
import os

def remove_file_reference(project_path, filename):
    """Remove a file reference from the Xcode project."""
    
    # Read the project file
    with open(project_path, 'rb') as f:
        project = plistlib.load(f)
    
    # Create backup
    backup_path = project_path + '.backup2'
    shutil.copy2(project_path, backup_path)
    print(f"Created backup at {backup_path}")
    
    objects = project['objects']
    
    # Find and remove file references
    refs_to_remove = []
    for obj_id, obj in objects.items():
        if obj.get('isa') == 'PBXFileReference':
            if obj.get('path') == filename:
                refs_to_remove.append(obj_id)
                print(f"Found file reference: {obj_id}")
    
    # Find and remove build file references
    build_files_to_remove = []
    for obj_id, obj in objects.items():
        if obj.get('isa') == 'PBXBuildFile':
            file_ref = obj.get('fileRef')
            if file_ref in refs_to_remove:
                build_files_to_remove.append(obj_id)
                print(f"Found build file: {obj_id}")
    
    # Remove from build phases
    for obj_id, obj in objects.items():
        if obj.get('isa') == 'PBXSourcesBuildPhase':
            files = obj.get('files', [])
            original_count = len(files)
            obj['files'] = [f for f in files if f not in build_files_to_remove]
            if len(obj['files']) != original_count:
                print(f"Removed from sources build phase: {obj_id}")
    
    # Remove from groups
    for obj_id, obj in objects.items():
        if obj.get('isa') == 'PBXGroup':
            children = obj.get('children', [])
            original_count = len(children)
            obj['children'] = [c for c in children if c not in refs_to_remove]
            if len(obj['children']) != original_count:
                print(f"Removed from group: {obj_id}")
    
    # Remove the build file objects
    for bf_id in build_files_to_remove:
        if bf_id in objects:
            del objects[bf_id]
            print(f"Deleted build file object: {bf_id}")
    
    # Remove the file reference objects
    for ref_id in refs_to_remove:
        if ref_id in objects:
            del objects[ref_id]
            print(f"Deleted file reference object: {ref_id}")
    
    # Write the modified project back
    with open(project_path, 'wb') as f:
        plistlib.dump(project, f)
    
    print(f"Successfully removed {filename} references from project!")
    return True

if __name__ == '__main__':
    project_path = '/Users/nataliewhipps/Desktop/Prompt28/Prompt28.xcodeproj/project.pbxproj'
    
    if not os.path.exists(project_path):
        print(f"Error: Project file not found at {project_path}")
        exit(1)
    
    try:
        remove_file_reference(project_path, 'Glassmorphism.swift')
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()
        exit(1)
