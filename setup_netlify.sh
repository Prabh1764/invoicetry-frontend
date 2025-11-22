#!/bin/bash

echo "🚀 Setting up Netlify Automated Deployment"
echo ""

# Check if Netlify CLI is installed
if ! command -v netlify &> /dev/null; then
    echo "📦 Installing Netlify CLI..."
    npm install -g netlify-cli
else
    echo "✅ Netlify CLI already installed"
fi

echo ""
echo "🔐 Step 1: Login to Netlify"
echo "   This will open your browser to authorize..."
netlify login

echo ""
echo "🔗 Step 2: Link to Netlify site"
echo "   If you have an existing site, enter the site ID"
echo "   Otherwise, we'll create a new site..."
netlify init

echo ""
echo "📤 Step 3: Deploy to production"
echo "   Deploying your app..."
netlify deploy --prod

echo ""
echo "✅ Done! Your app is now live!"
echo "   Check your Netlify dashboard for the URL"
echo ""
echo "🔄 Future deployments:"
echo "   Just run: netlify deploy --prod"
echo "   Or push to GitHub for auto-deployment"

