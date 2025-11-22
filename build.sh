#!/bin/bash
set -e

# Save the original working directory (Vercel's project root)
ORIGINAL_DIR="$(pwd)"
echo "📁 Original directory: $ORIGINAL_DIR"

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

# Return to project directory
cd "$ORIGINAL_DIR"
echo "📁 Back to project directory: $(pwd)"

# Verify we're in the right place
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found in: $(pwd)"
  echo "📁 Listing current directory:"
  ls -la
  exit 1
fi

echo "✅ Found pubspec.yaml at: $(pwd)"

echo "📦 Getting Flutter dependencies..."
if ! flutter pub get; then
  echo "❌ Failed to get dependencies"
  exit 1
fi

echo "🔨 Building Flutter web app..."
# Build and capture exit code
if ! flutter build web --release --base-href=/ 2>&1; then
  echo "❌ Build failed!"
  echo "📋 Running flutter analyze to see errors..."
  flutter analyze || true
  exit 1
fi

echo "✅ Build complete!"
