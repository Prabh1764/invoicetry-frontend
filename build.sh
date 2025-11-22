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

# Go to project directory
cd "$VERCEL_SOURCE_DIR" || cd "$(pwd)"

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo "🔨 Building Flutter web app..."
flutter build web --release --base-href=/

echo "✅ Build complete!"
