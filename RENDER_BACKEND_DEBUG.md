# 🔧 Debugging Render Backend 502 Error

## Problem
The backend is returning **502 Bad Gateway**, which means the service is not running or crashed.

## Quick Checks

### 1. Check Render Dashboard
1. Go to: https://dashboard.render.com
2. Find service: `invoictry-backend-1`
3. Check **Status**:
   - ✅ **Live** = Service is running (but might be sleeping)
   - ❌ **Build failed** = Build error (check logs)
   - ❌ **Crashed** = Service crashed (check logs)

### 2. Check Service Logs
1. In Render dashboard, click on `invoictry-backend-1`
2. Go to **Logs** tab
3. Look for:
   - ❌ `Error: Cannot find module`
   - ❌ `Error: P1001: Can't reach database`
   - ❌ `Error: listen EADDRINUSE`
   - ❌ `Error: EACCES: permission denied`

### 3. Common Issues

#### Issue 1: Service is Sleeping (Free Tier)
**Symptom:** First request takes 30-90 seconds, then works.

**Solution:** 
- Wait 30-60 seconds for first request
- Or upgrade to paid plan (keeps service always on)

#### Issue 2: Database Connection Failed
**Symptom:** Logs show `P1001: Can't reach database server`

**Solution:**
1. Check `DATABASE_URL` in Render environment variables
2. Should use **internal database URL** (ends with `-a` not `-a.oregon-postgres.render.com`)
3. Format: `postgresql://user:pass@dpg-xxx-xxx-a/dbname`

#### Issue 3: Service Crashed on Startup
**Symptom:** Service shows "Crashed" status

**Solution:**
1. Check logs for startup errors
2. Common causes:
   - Missing environment variables (`JWT_SECRET`, `DATABASE_URL`)
   - Port not listening on `0.0.0.0:3000`
   - Prisma migrations failing

#### Issue 4: Build Failed
**Symptom:** Service shows "Build failed"

**Solution:**
1. Check build logs
2. Common causes:
   - Dockerfile syntax error
   - Missing files in repo
   - npm install errors

## Manual Restart

1. In Render dashboard, click **Manual Deploy**
2. Select **Deploy latest commit**
3. Wait for build to complete

## Test Backend Health

```bash
curl https://invoictry-backend-1.onrender.com/health
```

**Expected response:**
```json
{"status":"ok","db":true}
```

**If 502 Bad Gateway:**
- Service is not running
- Check Render dashboard for status

**If timeout:**
- Service is sleeping (free tier)
- Wait 30-60 seconds and try again

## Environment Variables Checklist

Make sure these are set in Render:
- ✅ `DATABASE_URL` (internal URL)
- ✅ `JWT_SECRET` (random string)
- ✅ `SIGNED_URL_SECRET` (random string)
- ✅ `NODE_ENV=production`
- ✅ `PORT=3000` (optional, Render sets this automatically)

## Next Steps

1. Check Render dashboard status
2. Review logs for errors
3. Verify environment variables
4. Try manual restart
5. If still failing, share the error logs

