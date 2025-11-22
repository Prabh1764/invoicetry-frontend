#!/bin/bash
set -e

echo "🚀 Installing Flutter..."

# Install Flutter
FLUTTER_VERSION="3.24.0"
FLUTTER_CHANNEL="stable"

# Download Flutter
cd /tmp
wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz || \
wget -q https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.0-stable.tar.xz

# Extract Flutter
tar xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz || tar xf flutter_linux_3.24.0-stable.tar.xz
export PATH="$PATH:/tmp/flutter/bin"

# Verify Flutter installation
flutter --version

# Go back to project directory
cd "$VERCEL_SOURCE_DIR" || cd "$(pwd)"

echo "📦 Getting Flutter dependencies..."
flutter pub get

echo "🔨 Building Flutter web app..."
flutter build web --release --base-href=/

echo "✅ Build complete!"

