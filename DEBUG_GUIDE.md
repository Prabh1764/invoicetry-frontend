# 🔍 How to Debug on Mac

## Open Browser Console

### Chrome/Edge (Recommended)
1. **Press:** `Cmd + Option + I` (⌘⌥I)
2. **Or:** Right-click page → "Inspect" → Click "Console" tab
3. **Or:** View menu → Developer → Developer Tools

### Safari
1. **Enable Developer menu first:**
   - Safari → Settings (Preferences)
   - Click "Advanced" tab
   - Check ✅ "Show Develop menu in menu bar"
2. **Then press:** `Cmd + Option + C` (⌘⌥C)
3. **Or:** Develop menu → Show JavaScript Console

### Firefox
- Press: `Cmd + Option + K` (⌘⌥K)

## What to Check

### 1. Console Tab
Look for:
- ❌ **Red errors** - These are problems
- ⚠️ **Yellow warnings** - Usually OK but check
- ✅ **Blue info logs** - Look for: `🌐 [API_CLIENT] Running in production`

### 2. Network Tab
1. Click **Network** tab in DevTools
2. Try logging in
3. Look for requests to:
   - ✅ `invoictry-backend-1.onrender.com` (GOOD - connecting to backend)
   - ❌ `localhost:3000` (BAD - wrong URL)

### 3. Check Login Request
1. In Network tab, find request to `/auth/login`
2. Click on it
3. Check:
   - **Status:** Should be `200` (success) or `401` (wrong password)
   - **Request URL:** Should contain `onrender.com`
   - **Response:** Should show JSON with `accessToken`

## Common Issues

### "Failed to fetch" or "Network error"
- Backend might be sleeping (Render free tier)
- Wait 30 seconds and try again
- Check: https://invoictry-backend-1.onrender.com/health

### "401 Unauthorized"
- Wrong email/password
- Try: `demo@probilling.app` / `demo1234`

### "CORS error"
- Backend CORS not configured
- Should be fixed, but check backend logs

## Quick Test

Open console and type:
```javascript
fetch('https://invoictry-backend-1.onrender.com/health')
  .then(r => r.json())
  .then(console.log)
```

Should return: `{status: "ok", db: true}`

