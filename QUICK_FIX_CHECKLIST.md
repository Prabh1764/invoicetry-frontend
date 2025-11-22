# Quick Fix Checklist - All Issues

## Step 1: Check Environment Variables on Render

Go to [Render Dashboard](https://dashboard.render.com/) → Your Backend → Environment tab

### Must Have (Critical):
- [ ] `DATABASE_URL` - Should be your Render PostgreSQL internal URL
- [ ] `JWT_SECRET` - Any random string (e.g., `my-secret-key-123`)
- [ ] `SIGNED_URL_SECRET` - Any random string
- [ ] `SIGNED_URL_TTL_SECONDS` - `900` (15 minutes)

### For Features to Work:
- [ ] `OPENAI_API_KEY` - For AI enhancement (get from https://platform.openai.com/)
- [ ] `GOOGLE_CLIENT_ID` - For Google Drive
- [ ] `GOOGLE_CLIENT_SECRET` - For Google Drive  
- [ ] `GOOGLE_REDIRECT_URI` - `https://your-backend.onrender.com/google-drive/callback`
- [ ] `STRIPE_SECRET_KEY` or `STRIPE_SECRET_KEY_TEST` - For payment links

## Step 2: Test Each Feature

### Test Settings Save:
1. Open app → Settings
2. Change "Company Name"
3. Click "Save Settings"
4. **Check browser console (F12)** - What error do you see?
5. **Check Network tab** - What's the response status?

### Test Google Drive:
1. Settings → Google Drive tab
2. Click "Connect Google Drive"
3. **If error**: Check if `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set in Render

### Test Payment Links:
1. Open an invoice
2. Click "Create Payment Link"
3. **If error**: Check if `STRIPE_SECRET_KEY` is set in Render

### Test PDF Generation:
1. Open an invoice
2. Click "Generate PDF"
3. **Check Render logs** - What error appears?

## Step 3: Common Fixes

### If Settings Don't Save:
- **401 Error**: Log out and log back in (token expired)
- **400 Error**: Check the error message in Network tab response
- **500 Error**: Check Render logs for specific error

### If Google Drive Doesn't Work:
- Add `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI` to Render
- Make sure redirect URI matches Google Cloud Console

### If Payment Links Don't Work:
- Add `STRIPE_SECRET_KEY` or `STRIPE_SECRET_KEY_TEST` to Render
- Get keys from https://dashboard.stripe.com/

### If PDF Generation Doesn't Work:
- Check Render logs for Puppeteer errors
- Make sure invoice has items and client

## Step 4: Get Detailed Error Messages

1. **Open browser console** (F12)
2. **Try the action** (save settings, generate PDF, etc.)
3. **Copy the error message** from console
4. **Check Network tab** → Find the failed request → Check Response tab
5. **Check Render logs** → Look for errors when you try the action

## What to Share

When reporting issues, please provide:
1. **Browser console error** (screenshot or copy text)
2. **Network tab** - Failed request details (status code, response)
3. **Render logs** - Backend error messages
4. **What you tried** - Exact steps
5. **What happened** - Error message or behavior

