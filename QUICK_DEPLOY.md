# ⚡ Quick Deploy - Run These Commands

## Step 1: Login to Netlify
```bash
cd frontend
netlify login
```
This opens your browser - click "Authorize"

## Step 2: Initialize Site
```bash
netlify init
```
Choose:
- **Create & configure a new site** (if first time)
- Enter site name (e.g., `probilling` or press Enter for random)
- **No** to build command (we have netlify.toml)
- **No** to deploy now (we'll do it next)

## Step 3: Deploy!
```bash
netlify deploy --prod
```

## ✅ Done!
Your app is live! Check the URL Netlify gives you.

## 🔄 Auto-Deploy with GitHub (Optional)

To auto-deploy on every push:

1. **Create GitHub repo:**
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin YOUR_GITHUB_REPO_URL
   git push -u origin main
   ```

2. **In Netlify Dashboard:**
   - Site settings → Build & deploy → Continuous Deployment
   - Connect to GitHub
   - Select your repo
   - Done! Every push auto-deploys

## 📱 Test Your PWA

1. Open the Netlify URL on your phone
2. Tap browser menu → "Add to Home Screen"
3. App installs like native!

