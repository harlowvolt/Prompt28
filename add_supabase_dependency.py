#!/usr/bin/env python3
"""
Script to add Supabase Swift SDK dependency to the Xcode project.
This modifies the project.pbxproj file to add the supabase-swift package.
"""

import plistlib
import uuid
import sys
import shutil
import os

def generate_uuid():
    """Generate a UUID in Xcode format (uppercase without dashes)."""
    return str(uuid.uuid4()).upper().replace("-", "")

def add_supabase_to_project(project_path):
    """Add Supabase Swift SDK to the Xcode project."""
    
    # Read the project file
    with open(project_path, 'rb') as f:
        project = plistlib.load(f)
    
    # Create backup
    backup_path = project_path + '.backup'
    shutil.copy2(project_path, backup_path)
    print(f"Created backup at {backup_path}")
    
    objects = project['objects']
    root_object_id = project['rootObject']
    
    # Generate IDs for new objects
    package_ref_id = generate_uuid()
    package_dependency_id = generate_uuid()
    product_dependency_id = generate_uuid()
    
    # 1. Create XCRemoteSwiftPackageReference for Supabase
    package_ref = {
        'isa': 'XCRemoteSwiftPackageReference',
        'repositoryURL': 'https://github.com/supabase/supabase-swift',
        'requirement': {
            'kind': 'upToNextMajorVersion',
            'minimumVersion': '2.5.0'
        }
    }
    objects[package_ref_id] = package_ref
    
    # 2. Create XCSwiftPackageProductDependency for Supabase
    product_dependency = {
        'isa': 'XCSwiftPackageProductDependency',
        'package': package_ref_id,
        'productName': 'Supabase'
    }
    objects[product_dependency_id] = product_dependency
    
    # 3. Add package reference to project's packageReferences
    if 'packageReferences' not in objects[root_object_id]:
        objects[root_object_id]['packageReferences'] = []
    objects[root_object_id]['packageReferences'].append(package_ref_id)
    
    # 4. Find the main target (OrionOrb) and add the product dependency
    # First, find all native targets
    for obj_id, obj in objects.items():
        if obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'OrionOrb':
            # Add package product dependency to the target
            if 'packageProductDependencies' not in obj:
                obj['packageProductDependencies'] = []
            obj['packageProductDependencies'].append(product_dependency_id)
            print(f"Added Supabase dependency to target: {obj.get('name')}")
            break
    
    # 5. Find the frameworks build phase and add the product dependency
    for obj_id, obj in objects.items():
        if obj.get('isa') == 'PBXFrameworksBuildPhase':
            # Check if this belongs to our main target by looking at files
            # We'll add a reference to the product dependency
            if 'files' not in obj:
                obj['files'] = []
            # Note: In newer Xcode versions, package dependencies are handled differently
            # The product dependency ID is sufficient
            print(f"Found frameworks build phase: {obj_id}")
    
    # Write the modified project back
    with open(project_path, 'wb') as f:
        plistlib.dump(project, f)
    
    print("Successfully added Supabase Swift SDK to the project!")
    print(f"Package Reference ID: {package_ref_id}")
    print(f"Product Dependency ID: {product_dependency_id}")
    
    return True

if __name__ == '__main__':
    project_path = '/Users/nataliewhipps/Desktop/Prompt28/Prompt28.xcodeproj/project.pbxproj'
    
    if not os.path.exists(project_path):
        print(f"Error: Project file not found at {project_path}")
        sys.exit(1)
    
    try:
        add_supabase_to_project(project_path)
    except Exception as e:
        print(f"Error: {e}")
        # Restore backup if something went wrong
        backup_path = project_path + '.backup'
        if os.path.exists(backup_path):
            shutil.copy2(backup_path, project_path)
            print("Restored from backup due to error")
        sys.exit(1)
