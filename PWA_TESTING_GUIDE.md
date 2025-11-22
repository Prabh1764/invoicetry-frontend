# PWA Testing Guide

## Quick Test Steps

### 1. Start the App
```bash
cd frontend
flutter run -d chrome --web-port=8080
```

### 2. Open Chrome DevTools
- Press `F12` or `Cmd+Option+I` (Mac) / `Ctrl+Shift+I` (Windows)
- Go to **Application** tab

### 3. Check PWA Status
In the Application tab:
- **Manifest**: Should show "ProBilling - Invoice Manager"
- **Service Workers**: Should show `flutter_service_worker.js` registered
- **Storage**: Check if data is being stored

### 4. Test Install Prompt
- Look for install icon in Chrome address bar
- Or go to Chrome menu → "Install ProBilling"
- App should install and open in standalone window

### 5. Test Backend Connection
- Open **Console** tab in DevTools
- Look for: `🌐 [API_CLIENT] Using Render backend URL from .env for web`
- Try logging in - should connect to: `https://invoictry-backend-1.onrender.com`

### 6. Test Offline Mode
- In DevTools → **Network** tab → Check "Offline"
- App should still work (service worker caching)

## Expected Results

✅ **PWA Features Working:**
- App installs on device
- Opens in standalone window (no browser UI)
- Service worker registered
- Offline functionality works
- Icons display correctly

✅ **Backend Connection:**
- API calls go to Render backend
- Login/register works
- Data loads from cloud

## Troubleshooting

**If backend connection fails:**
1. Check `.env` has: `BACKEND_BASE_URL=https://invoictry-backend-1.onrender.com`
2. Check Render dashboard: https://dashboard.render.com/web/srv-d4d69a24d50c73discqg
3. Check browser console for CORS errors

**If PWA doesn't install:**
1. Must be served over HTTPS (or localhost)
2. Manifest must be valid
3. Service worker must be registered
4. Icons must be accessible

## Deploy to Production

To make PWA fully functional:
1. Deploy `build/web` to:
   - **Netlify** (free, easy)
   - **Vercel** (free, easy)
   - **GitHub Pages** (free)
2. Use HTTPS (required for PWA)
3. Test install on mobile device

