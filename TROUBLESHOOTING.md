# 🔧 Troubleshooting Login Issues

## CSP Warning (Not the Problem)
The CSP warning you see is just a **warning** - it won't prevent login from working. Flutter web needs `unsafe-eval` to run, which I've now added to the CSP.

## Real Issues to Check

### 1. Backend Might Be Sleeping (Render Free Tier)
Render free tier puts apps to sleep after 15 minutes of inactivity.

**Check:**
- Open: https://invoictry-backend-1.onrender.com/health
- If it takes 30+ seconds to load → Backend is sleeping
- Wait for it to wake up, then try login again

### 2. Check Network Tab
1. Open Console (`Cmd + Option + I`)
2. Go to **Network** tab
3. Try logging in
4. Look for request to `/auth/login`
5. Check:
   - **URL:** Should be `https://invoictry-backend-1.onrender.com/auth/login`
   - **Status:** 
     - `200` = Success (but check response)
     - `401` = Wrong password
     - `0` or `Failed` = Backend not reachable (sleeping or CORS)

### 3. Check Console for Errors
Look for:
- ❌ `Failed to fetch` → Backend sleeping or CORS issue
- ❌ `CORS policy` → Backend CORS not configured (should be fixed)
- ❌ `401 Unauthorized` → Wrong credentials

### 4. Test Backend Directly
In browser console, paste:
```javascript
fetch('https://invoictry-backend-1.onrender.com/health')
  .then(r => r.json())
  .then(d => console.log('Backend status:', d))
  .catch(e => console.error('Backend error:', e))
```

Should return: `{status: "ok", db: true}`

### 5. Test Login Directly
In browser console:
```javascript
fetch('https://invoictry-backend-1.onrender.com/auth/login', {
  method: 'POST',
  headers: {'Content-Type': 'application/json'},
  body: JSON.stringify({
    email: 'demo@probilling.app',
    password: 'demo1234'
  })
})
.then(r => r.json())
.then(d => console.log('Login response:', d))
.catch(e => console.error('Login error:', e))
```

## Quick Fixes

### If Backend is Sleeping:
- Wait 30-60 seconds for first request
- Or upgrade Render plan (keeps it always on)

### If CORS Error:
- Backend should allow all origins (already configured)
- Check backend logs in Render dashboard

### If Wrong Password:
- Try: `demo@probilling.app` / `demo1234`
- Or create new account via register

