# Deploy Frontend to Render - Step by Step

## Prerequisites
- ✅ Backend already on Render
- ✅ Frontend code in GitHub
- ✅ Git token available

## Step 1: Create Static Site on Render

1. Go to **Render Dashboard**: https://dashboard.render.com/
2. Click **"New +"** → **"Static Site"**
3. Connect your GitHub account (if not already connected)
4. Select your repository: `invoicetry-frontend` (or your frontend repo name)
5. Configure the service:

### Settings:
- **Name**: `invoicetry-frontend`
- **Branch**: `main` (or your default branch)
- **Root Directory**: Leave empty (or `frontend` if your repo has frontend in a subfolder)
- **Build Command**: `bash build.sh`
- **Publish Directory**: `build/web`

### Environment Variables (Optional):
- `FLUTTER_VERSION`: `3.24.0` (optional, build script will handle it)

6. Click **"Create Static Site"**

## Step 2: Wait for First Deployment

- Render will automatically start building
- This may take 5-10 minutes (first time installs Flutter)
- Watch the logs to see progress

## Step 3: Verify Deployment

1. Once deployed, Render will give you a URL like: `https://invoicetry-frontend.onrender.com`
2. Open the URL in browser
3. Your app should load!

## Step 4: Update Custom Domain (Optional)

1. In Render Dashboard → Your Static Site → Settings
2. Add your custom domain (if you have one)
3. Update DNS records as instructed

## Step 5: Verify Backend Connection

1. Open your deployed frontend
2. Check browser console (F12) → Network tab
3. Verify requests go to: `https://invoictry-backend.onrender.com`
4. If not, check `api_client.dart` has correct backend URL

## Troubleshooting

### Build Fails
- Check Render logs for errors
- Verify `build.sh` has execute permissions
- Make sure `pubspec.yaml` is in root directory

### App Shows Blank Page
- Check browser console for errors
- Verify `build/web/index.html` exists
- Check if backend URL is correct

### 404 Errors
- Verify `--base-href=/` is in build command
- Check Render static site settings

## Benefits of Render

✅ **One Dashboard** - Frontend and backend in same place
✅ **Automatic Deploys** - Deploys on every git push
✅ **Free Tier** - Both services on free tier
✅ **Easy Management** - All in one place

## Next Steps

After deployment:
1. Test all features (login, PDF, email, etc.)
2. Update any hardcoded URLs if needed
3. Set up custom domain (optional)
4. Monitor logs for any issues

---

**Note**: The build script (`build.sh`) will automatically install Flutter and build your app. First deployment may take longer.

