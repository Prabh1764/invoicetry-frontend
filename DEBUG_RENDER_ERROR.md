# Debug "instance of minifield ws" Error

## Quick Checks

### 1. Check Browser Console
1. Open your Render URL
2. Press **F12** (Developer Tools)
3. Go to **Console** tab
4. **Copy the exact error message** you see
5. Share it with me

### 2. Check Network Tab
1. Stay in Developer Tools → **Network** tab
2. Refresh the page
3. Look for files with **red status** (404, 500, etc.)
4. Check which files are failing to load

### 3. Check Render Logs
1. Render Dashboard → Your Static Site → **Logs**
2. Scroll to the latest build
3. Look for any errors or warnings
4. Check if build completed successfully

## Common Causes

### Cause 1: Missing JavaScript Files
**Symptom**: Console shows "Failed to load resource"
**Fix**: Check if `main.dart.js` and `flutter.js` exist in build output

### Cause 2: Base Href Issue
**Symptom**: Files loading from wrong path
**Fix**: Verify build command has `--base-href=/`

### Cause 3: CORS or CSP Issues
**Symptom**: Console shows CORS or CSP errors
**Fix**: Render static sites don't need CSP headers (unlike Netlify)

### Cause 4: Build Output Wrong Directory
**Symptom**: 404 errors for all files
**Fix**: Verify Publish Directory is `build/web`

## What to Share

When asking for help, share:
1. **Exact error from browser console** (screenshot or copy text)
2. **Network tab errors** (which files are 404?)
3. **Render build logs** (any errors during build?)
4. **Your Render URL** (so I can check)

## Quick Fixes to Try

### Fix 1: Clear Cache & Rebuild
1. Render Dashboard → Your Static Site
2. Click "Manual Deploy" → "Clear build cache & deploy"
3. Wait for rebuild

### Fix 2: Verify Build Settings
- Build Command: `bash build.sh`
- Publish Directory: `build/web`
- Root Directory: (empty)

### Fix 3: Check File Structure
After build, `build/web` should contain:
- `index.html`
- `main.dart.js`
- `flutter.js`
- `flutter_bootstrap.js`
- `manifest.json`
- `assets/` folder
- `canvaskit/` folder

---

**Next Step**: Check browser console and share the exact error message!

