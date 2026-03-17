#!/usr/bin/env python3
"""
Add missing files to Xcode project
"""
import plistlib
import subprocess
import sys
import uuid
import os

def generate_uuid():
    return ''.join(str(uuid.uuid4()).upper().split('-'))

def main():
    project_path = "/Users/nataliewhipps/Desktop/Prompt28/Prompt28.xcodeproj/project.pbxproj"
    
    # Convert to XML
    xml_path = "/tmp/project.pbxproj.xml"
    subprocess.run(["plutil", "-convert", "xml1", "-o", xml_path, project_path], check=True)
    
    # Read the plist
    with open(xml_path, 'rb') as f:
        plist = plistlib.load(f)
    
    # Generate new UUIDs for our files
    telemetry_file_id = generate_uuid()
    telemetry_build_id = generate_uuid()
    cloudkit_file_id = generate_uuid()
    cloudkit_build_id = generate_uuid()
    
    print(f"TelemetryService.swift: file={telemetry_file_id}, build={telemetry_build_id}")
    print(f"CloudKitService.swift: file={cloudkit_file_id}, build={cloudkit_build_id}")
    
    # Add file references
    # TelemetryService in Utils group
    if telemetry_file_id not in plist['objects']:
        plist['objects'][telemetry_file_id] = {
            'isa': 'PBXFileReference',
            'lastKnownFileType': 'sourcecode.swift',
            'path': 'TelemetryService.swift',
            'sourceTree': '<group>'
        }
        print(f"Added TelemetryService file reference")
    
    # CloudKitService in Storage group  
    if cloudkit_file_id not in plist['objects']:
        plist['objects'][cloudkit_file_id] = {
            'isa': 'PBXFileReference',
            'lastKnownFileType': 'sourcecode.swift',
            'path': 'CloudKitService.swift',
            'sourceTree': '<group>'
        }
        print(f"Added CloudKitService file reference")
    
    # Add build file references
    if telemetry_build_id not in plist['objects']:
        plist['objects'][telemetry_build_id] = {
            'isa': 'PBXBuildFile',
            'fileRef': telemetry_file_id
        }
        print(f"Added TelemetryService build reference")
    
    if cloudkit_build_id not in plist['objects']:
        plist['objects'][cloudkit_build_id] = {
            'isa': 'PBXBuildFile', 
            'fileRef': cloudkit_file_id
        }
        print(f"Added CloudKitService build reference")
    
    # Find and update groups
    # Find Utils group and add TelemetryService
    for key, obj in plist['objects'].items():
        if obj.get('isa') == 'PBXGroup' and obj.get('path') == 'Utils':
            if 'children' in obj:
                if telemetry_file_id not in obj['children']:
                    obj['children'].append(telemetry_file_id)
                    print(f"Added TelemetryService to Utils group ({key})")
            break
    
    # Find Storage group and add CloudKitService
    for key, obj in plist['objects'].items():
        if obj.get('isa') == 'PBXGroup' and obj.get('path') == 'Storage':
            if 'children' in obj:
                if cloudkit_file_id not in obj['children']:
                    obj['children'].append(cloudkit_file_id)
                    print(f"Added CloudKitService to Storage group ({key})")
            break
    
    # Find main target's Sources build phase and add both files
    main_target_id = None
    for key, obj in plist['objects'].items():
        if obj.get('isa') == 'PBXNativeTarget' and obj.get('name') == 'OrionOrb':
            main_target_id = key
            print(f"Found OrionOrb target: {key}")
            break
    
    if main_target_id:
        target = plist['objects'][main_target_id]
        for build_phase_id in target.get('buildPhases', []):
            build_phase = plist['objects'].get(build_phase_id)
            if build_phase and build_phase.get('isa') == 'PBXSourcesBuildPhase':
                if 'files' not in build_phase:
                    build_phase['files'] = []
                
                if telemetry_build_id not in build_phase['files']:
                    build_phase['files'].append(telemetry_build_id)
                    print(f"Added TelemetryService to Sources build phase")
                
                if cloudkit_build_id not in build_phase['files']:
                    build_phase['files'].append(cloudkit_build_id)
                    print(f"Added CloudKitService to Sources build phase")
                break
    
    # Write back
    with open(xml_path, 'wb') as f:
        plistlib.dump(plist, f)
    
    # Convert back to binary
    subprocess.run(["plutil", "-convert", "binary1", "-o", project_path, xml_path], check=True)
    
    print("\n✅ Project file updated successfully!")
    print("Now build in Xcode or run: xcodebuild -project Prompt28.xcodeproj -scheme OrionOrb build")

if __name__ == '__main__':
    main()
