#!/bin/bash
# Quick check script for common build issues

echo "🔍 Checking for common build issues..."
echo ""

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    echo "❌ Error: pubspec.yaml not found!"
    echo "   Make sure you're in the frontend directory"
    exit 1
fi

echo "✅ Found pubspec.yaml"

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo "⚠️  Flutter not found in PATH"
    echo "   Install Flutter: https://flutter.dev/docs/get-started/install"
else
    echo "✅ Flutter found: $(flutter --version | head -1)"
fi

# Check for common import issues
echo ""
echo "🔍 Checking for common import issues..."

MISSING_IMPORTS=0

# Check if AuthToken is imported where needed
if grep -q "AsyncValue<AuthToken" lib/features/auth/login_screen.dart && ! grep -q "import.*auth_token.dart" lib/features/auth/login_screen.dart; then
    echo "❌ Missing AuthToken import in login_screen.dart"
    MISSING_IMPORTS=$((MISSING_IMPORTS + 1))
fi

# Check for unused imports that might cause issues
echo ""
echo "🔍 Running Flutter analyze (quick check)..."
if command -v flutter &> /dev/null; then
    flutter analyze --no-fatal-infos 2>&1 | grep -E "error|Error" | head -10
    if [ $? -eq 0 ]; then
        echo ""
        echo "❌ Found compilation errors above"
        echo "   Run 'flutter analyze' for full details"
    else
        echo "✅ No critical errors found"
    fi
else
    echo "⚠️  Flutter not available, skipping analyze"
fi

echo ""
echo "✅ Check complete!"
echo ""
echo "💡 Tips:"
echo "   - Run 'flutter analyze' for full analysis"
echo "   - Check Render logs: ./fetch-render-logs.sh"
echo "   - View Render dashboard: https://dashboard.render.com"

