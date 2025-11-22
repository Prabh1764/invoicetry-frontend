# 🚀 Vercel Deployment Setup

## ✅ What I've Done

1. **Created build script** (`build.sh`) that:
   - Installs Flutter automatically
   - Gets dependencies
   - Builds the web app

2. **Updated vercel.json** to use the build script

## 📋 Vercel Settings

In Vercel dashboard, configure:

- **Framework Preset:** Other
- **Build Command:** (Leave empty - uses build.sh automatically)
- **Output Directory:** `build/web`
- **Root Directory:** (Leave empty)
- **Install Command:** (Leave empty)

OR just use the `vercel.json` file - Vercel will read it automatically!

## 🔄 After Pushing

1. Vercel will automatically detect the new commit
2. It will run the build script
3. Flutter will be installed automatically
4. Your app will be built and deployed!

## ⚠️ If Build Still Fails

If you see errors, the build script might need adjustments. Common issues:
- Flutter download might be slow (first time)
- Network issues during git clone

Let me know if you see any errors and I'll fix them!

