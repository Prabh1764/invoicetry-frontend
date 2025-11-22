#!/bin/bash
set -e

echo "🚀 Installing Flutter..."

# Install Flutter using git (more reliable)
cd /tmp
if [ ! -d "flutter" ]; then
  echo "📥 Cloning Flutter repository..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:/tmp/flutter/bin"

# Verify Flutter installation
flutter --version

# Navigate to project directory
# Vercel sets VERCEL_SOURCE_DIR, but we need to find the actual project root
if [ -n "$VERCEL_SOURCE_DIR" ]; then
  cd "$VERCEL_SOURCE_DIR"
else
  # Try to find the project root by looking for pubspec.yaml
  SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  cd "$SCRIPT_DIR"
fi

# Make sure we're in the right directory (should have pubspec.yaml)
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found in current directory: $(pwd)"
  echo "📁 Listing current directory:"
  ls -la
  exit 1
fi

echo "✅ Found project root at: $(pwd)"

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo "🔨 Building Flutter web app..."
flutter build web --release --base-href=/

echo "✅ Build complete!"
