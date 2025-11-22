# Quick Debug Guide

## 🚀 Fastest Way to Get Help

### 1. **Copy Render Logs** (30 seconds)
```bash
# Option A: Use the script
./fetch-render-logs.sh invoicetry-frontend 200

# Option B: Manual
# 1. Go to: https://dashboard.render.com/web/invoicetry-frontend/logs
# 2. Copy the last 50-100 lines
# 3. Paste them here
```

### 2. **Copy Browser Console Errors** (10 seconds)
1. Open your app: https://invoicetry-frontend.onrender.com
2. Press `F12` (or `Cmd+Option+I` on Mac)
3. Go to "Console" tab
4. Copy any red errors
5. Paste them here

### 3. **Check Build Status** (5 seconds)
```bash
./check-build-issues.sh
```

## 🔧 Common Issues & Quick Fixes

### Build Fails
**Symptom:** "Build failed 😞" in Render logs

**Quick Check:**
1. Look for `error •` (not `warning •` or `info •`)
2. Copy the error line
3. Share it here

**Common Causes:**
- Missing imports (like `AuthToken`)
- TypeScript/Dart syntax errors
- Missing dependencies

### App Shows Blank Page
**Symptom:** White screen, no content

**Quick Check:**
1. Open browser console (F12)
2. Look for red errors
3. Check Network tab for failed requests

**Common Causes:**
- JavaScript errors (minified:WR, etc.)
- Backend not responding
- Routing issues

### Can't Login
**Symptom:** Login button does nothing or shows error

**Quick Check:**
1. Check browser console for API errors
2. Check if backend is awake (first request takes 30-90s on free tier)
3. Verify backend URL in logs

## 📋 What to Share When Asking for Help

**Minimum Info Needed:**
1. **What you're trying to do:** "Login", "Generate PDF", etc.
2. **What happens:** "Blank page", "Error message", etc.
3. **Error from browser console:** Copy the red error
4. **Error from Render logs:** Last 20-30 lines

**Example:**
```
Trying to: Login
What happens: Blank white page
Browser console: "Error: Cannot read properties of null"
Render logs: [paste last 30 lines]
```

## 🛠️ Tools Created for You

1. **`fetch-render-logs.sh`** - Get Render logs quickly
2. **`check-build-issues.sh`** - Check for common issues
3. **This guide** - Quick reference

## 💡 Pro Tips

1. **Always check browser console first** - Most errors show there
2. **Render free tier has cold starts** - First request takes 30-90 seconds
3. **Build errors are usually import issues** - Check the error message
4. **Share the actual error, not just "it doesn't work"** - Much faster to fix!

## 🔗 Quick Links

- **Render Dashboard:** https://dashboard.render.com
- **Frontend Logs:** https://dashboard.render.com/web/invoicetry-frontend/logs
- **Backend Logs:** https://dashboard.render.com/web/invoictry-backend/logs
- **Your App:** https://invoicetry-frontend.onrender.com

