# Quick Setup: Frontend on Render

## ✅ Files Ready
- ✅ `render.yaml` - Render configuration
- ✅ `build.sh` - Build script (works for Render)
- ✅ `RENDER_DEPLOYMENT.md` - Detailed guide

## 🚀 Quick Steps (5 minutes)

### Step 1: Go to Render Dashboard
1. Open: https://dashboard.render.com/
2. Click **"New +"** button (top right)
3. Select **"Static Site"**

### Step 2: Connect Repository
1. If not connected, connect your GitHub account
2. Select repository: **`invoicetry-frontend`** (or your frontend repo)
3. Click **"Continue"**

### Step 3: Configure Settings

Fill in these exact values:

```
Name: invoicetry-frontend
Branch: main
Root Directory: (leave empty)
Build Command: bash build.sh
Publish Directory: build/web
```

### Step 4: Environment Variables (Optional)
Click "Advanced" → "Add Environment Variable":
- Key: `FLUTTER_VERSION`
- Value: `3.24.0`

(Optional - build script handles this)

### Step 5: Deploy
1. Click **"Create Static Site"**
2. Wait 5-10 minutes for first build
3. Watch the logs - you'll see Flutter installing and building

### Step 6: Done!
- Render will give you a URL like: `https://invoicetry-frontend.onrender.com`
- Your app will be live!

## 📋 What Happens

1. Render clones your repo
2. Runs `bash build.sh`
3. Build script installs Flutter
4. Builds your Flutter web app
5. Publishes `build/web` folder
6. Your app is live!

## ✅ Verification

1. Open the Render URL
2. Your app should load
3. Check browser console (F12) → Network tab
4. Verify requests go to: `https://invoictry-backend.onrender.com`

## 🎯 Benefits

- ✅ Frontend and backend in one dashboard
- ✅ Automatic deploys on git push
- ✅ Free tier for both
- ✅ Easy to manage

## ⚠️ First Build Takes Longer

- First time: 5-10 minutes (installs Flutter)
- After that: 2-3 minutes (just builds)

## 🆘 If Build Fails

1. Check Render logs
2. Verify `build.sh` exists and is executable
3. Make sure `pubspec.yaml` is in root
4. Check for any error messages in logs

---

**That's it!** Once deployed, both your frontend and backend will be on Render! 🎉

