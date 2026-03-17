#!/bin/bash

echo "🔧 Fixing Xcode Project - Adding all Swift files..."
echo ""

PROJECT_DIR="/Users/nataliewhipps/Desktop/Prompt28"
PROJECT_FILE="$PROJECT_DIR/Prompt28.xcodeproj/project.pbxproj"

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup.$(date +%s)"
echo "✅ Backed up project.pbxproj"

# The project has 68 Swift files in PromptMeNative_Blueprint
# but they're not linked in the Xcode project

echo ""
echo "📁 Found Swift files:"
find "$PROJECT_DIR/PromptMeNative_Blueprint" -name "*.swift" | wc -l
echo ""

echo "⚠️  IMPORTANT: Manual steps required in Xcode:"
echo ""
echo "1. Open Prompt28.xcodeproj in Xcode"
echo "2. In Project Navigator, look for 'PromptMeNative_Blueprint' folder"
echo "3. If it exists, select it and press Delete → Choose 'Remove References'"
echo ""
echo "4. Right-click in Project Navigator (empty area)"
echo "5. Select 'Add Files to Prompt28...'"
echo "6. Navigate to: /Users/nataliewhipps/Desktop/Prompt28/"
echo "7. SELECT the 'PromptMeNative_Blueprint' folder"
echo "8. IMPORTANT: Choose 'Create groups' (NOT 'Create folder references')"
echo "9. Check 'Copy items if needed' should be UNCHECKED (files already in place)"
echo "10. Make sure 'OrionOrb' target is selected"
echo "11. Click 'Add'"
echo ""
echo "This will add all 68 Swift files including the new OrionMainContainer.swift"
echo ""
echo "After adding, build the project (Cmd+B)"

