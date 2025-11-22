# Deploy PWA to Production

Your app is ready to deploy! Choose one of these free hosting options:

## Option 1: Netlify (Recommended - Easiest)

### Steps:
1. **Go to**: https://app.netlify.com
2. **Sign up** (free with GitHub)
3. **Drag and drop** the `build/web` folder to Netlify
4. **Done!** Your app will be live at: `https://your-app-name.netlify.app`

### Or use Netlify CLI:
```bash
# Install Netlify CLI
npm install -g netlify-cli

# Login
netlify login

# Deploy
cd frontend
netlify deploy --prod --dir=build/web
```

## Option 2: Vercel (Also Easy)

### Steps:
1. **Go to**: https://vercel.com
2. **Sign up** (free with GitHub)
3. **Import** your GitHub repo
4. **Set build command**: `flutter build web --release`
5. **Set output directory**: `build/web`
6. **Deploy!**

### Or use Vercel CLI:
```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
cd frontend
vercel --prod
```

## Option 3: GitHub Pages (Free)

### Steps:
1. **Push code to GitHub**
2. **Go to repo Settings → Pages**
3. **Select source**: GitHub Actions
4. **Create workflow** (see below)

## Important Notes:

✅ **Your backend is already live** at: `https://invoictry-backend-1.onrender.com`
✅ **PWA is configured** - will work once deployed
✅ **HTTPS required** for PWA install (all these services provide it)

## After Deployment:

1. **Test PWA install** on mobile device
2. **Test backend connection** - should work automatically
3. **Share the URL** - anyone can use it!

