# 🤖 Automated Deployment Setup

## Quick Setup (5 minutes)

### Option A: Netlify CLI (Recommended)

1. **Install Netlify CLI:**
   ```bash
   npm install -g netlify-cli
   ```

2. **Run setup script:**
   ```bash
   cd frontend
   ./setup_netlify.sh
   ```

3. **Or manually:**
   ```bash
   # Login
   netlify login
   
   # Initialize (creates new site or links existing)
   netlify init
   
   # Deploy
   netlify deploy --prod
   ```

### Option B: GitHub Integration (Auto-deploy on push)

1. **Push frontend to GitHub:**
   ```bash
   cd frontend
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin YOUR_GITHUB_REPO_URL
   git push -u origin main
   ```

2. **Connect to Netlify:**
   - Go to: https://app.netlify.com
   - Click "Add new site" → "Import an existing project"
   - Choose GitHub
   - Select your repo
   - Settings:
     - **Build command:** `flutter pub get && flutter build web --release`
     - **Publish directory:** `build/web`
   - Click "Deploy site"

3. **Done!** Every `git push` will auto-deploy

## Environment Variables

If needed, add in Netlify dashboard:
- `BACKEND_BASE_URL` = `https://invoictry-backend-1.onrender.com`

## Custom Domain (Optional)

1. Go to Netlify dashboard → Site settings → Domain management
2. Add custom domain (e.g., `probilling.com`)
3. Follow DNS setup instructions

## Continuous Deployment

Once set up:
- ✅ Every `git push` → Auto-deploys
- ✅ Preview deployments for PRs
- ✅ Rollback to previous versions
- ✅ HTTPS automatically enabled

