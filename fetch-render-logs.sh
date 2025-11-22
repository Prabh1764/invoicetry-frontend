#!/bin/bash
# Script to fetch Render logs easily
# Usage: ./fetch-render-logs.sh [service-name] [lines]

SERVICE_NAME="${1:-invoicetry-frontend}"
LINES="${2:-100}"

echo "📋 Fetching last $LINES lines from Render service: $SERVICE_NAME"
echo ""

# Check if render CLI is installed
if ! command -v render &> /dev/null; then
    echo "❌ Render CLI not found!"
    echo ""
    echo "📥 Install it with:"
    echo "   brew install render"
    echo ""
    echo "🔐 Then authenticate:"
    echo "   render auth login"
    echo ""
    echo "📖 Or view logs in browser:"
    echo "   https://dashboard.render.com/web/$SERVICE_NAME/logs"
    exit 1
fi

# Fetch logs
echo "🔍 Fetching logs..."
render logs "$SERVICE_NAME" --tail "$LINES"

echo ""
echo "✅ Done! For more logs, visit:"
echo "   https://dashboard.render.com/web/$SERVICE_NAME/logs"

