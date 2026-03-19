#!/bin/bash
# Script to add files to Xcode project
# Run: ./add_files_to_xcode.sh

echo "Adding TelemetryService.swift and CloudKitService.swift to Xcode project..."
echo ""
echo "Files exist at:"
ls -la PromptMeNative_Blueprint/Core/Utils/TelemetryService.swift
ls -la PromptMeNative_Blueprint/Core/Storage/CloudKitService.swift
echo ""
echo "Now you need to:"
echo "1. Open Prompt28.xcodeproj in Xcode"
echo "2. Right-click 'Utils' folder → Add Files to Prompt28"
echo "3. Select TelemetryService.swift"
echo "4. Right-click 'Storage' folder → Add Files to Prompt28"  
echo "5. Select CloudKitService.swift"
echo ""
echo "After adding, build should succeed."
