#!/bin/bash
set -e

echo "🚀 Starting Flutter build for Render..."

# Install Flutter
echo "📥 Installing Flutter..."
cd /tmp
if [ ! -d "flutter" ]; then
  echo "📥 Cloning Flutter repository..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

export PATH="$PATH:/tmp/flutter/bin"

# Verify Flutter installation
echo "✅ Flutter installed:"
flutter --version

# Return to project directory
cd "$RENDER_SOURCE_DIR" || cd "$(pwd)"
echo "📁 Working directory: $(pwd)"

# Verify we're in the right place
if [ ! -f "pubspec.yaml" ]; then
  echo "❌ Error: pubspec.yaml not found in: $(pwd)"
  echo "📁 Listing current directory:"
  ls -la
  exit 1
fi

echo "✅ Found pubspec.yaml"

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build web app
echo "🔨 Building Flutter web app..."
flutter build web --release --base-href=/

# Verify build output
if [ ! -d "build/web" ]; then
  echo "❌ Error: build/web directory not found!"
  exit 1
fi

# Copy _redirects file for Render SPA routing (if it exists)
if [ -f "public/_redirects" ]; then
  echo "📋 Copying _redirects file for SPA routing..."
  cp public/_redirects build/web/_redirects
  echo "✅ _redirects file copied"
fi

echo "✅ Build complete! Output in build/web"

