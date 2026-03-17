#!/usr/bin/env python3
"""
Add all Swift files to Xcode project
"""
import subprocess
import sys

def main():
    project_path = "/Users/nataliewhipps/Desktop/Prompt28/Prompt28.xcodeproj/project.pbxproj"
    blueprint_path = "/Users/nataliewhipps/Desktop/Prompt28/PromptMeNative_Blueprint"
    
    # Convert to XML
    xml_path = "/tmp/project_full.pbxproj.xml"
    subprocess.run(["plutil", "-convert", "xml1", "-o", xml_path, project_path], check=True)
    
    # Use plistutil to parse and modify
    # Find all Swift files
    import os
    swift_files = []
    for root, dirs, files in os.walk(blueprint_path):
        for file in files:
            if file.endswith('.swift'):
                full_path = os.path.join(root, file)
                rel_path = os.path.relpath(full_path, blueprint_path)
                swift_files.append(rel_path)
    
    print(f"Found {len(swift_files)} Swift files")
    for f in sorted(swift_files)[:10]:
        print(f"  - {f}")
    if len(swift_files) > 10:
        print(f"  ... and {len(swift_files) - 10} more")
    
    print("\n⚠️  Manual step required:")
    print("1. Open Prompt28.xcodeproj in Xcode")
    print("2. Delete the blue 'PromptMeNative_Blueprint' folder reference if it exists")
    print("3. Right-click in Project Navigator → 'Add Files to Prompt28'")
    print("4. Select the PromptMeNative_Blueprint folder")
    print("5. Choose 'Create groups' (NOT 'Create folder references')")
    print("6. Check 'Copy items if needed'")
    print("7. Select 'OrionOrb' target")
    print("8. Click 'Add'")
    print("\nThis will add all 68 Swift files in the correct structure.")

if __name__ == '__main__':
    main()
