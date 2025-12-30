# Deploying to Railway

This guide will help you deploy the Web Streamer to Railway using Docker.

## 🚂 Prerequisites

- A [Railway](https://railway.app) account
- Your project pushed to a Git repository (GitHub, GitLab, or Bitbucket)
- An RTMP/RTMPS URL for streaming

## 📦 Method 1: Deploy from GitHub (Recommended)

### Step 1: Push to GitHub

1. Create a new repository on GitHub
2. Push your code:
   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   git remote add origin https://github.com/yourusername/web-streamer.git
   git push -u origin main
   ```

### Step 2: Create a New Project on Railway

1. Go to [Railway Dashboard](https://railway.app/dashboard)
2. Click **"New Project"**
3. Select **"Deploy from GitHub repo"**
4. Choose your `web-streamer` repository
5. Railway will automatically detect the `Dockerfile` and start building

### Step 3: Configure Environment Variables

1. In your Railway project, go to the **Variables** tab
2. Add the following environment variables:

   **Required:**
   - `RTMP_URL`: Your RTMP/RTMPS server URL
     ```
     rtmps://pump-prod-tg2x8veh.rtmp.livekit.cloud/x/gb292QFSLYsp
     ```
     ⚠️ **Important**: Do NOT add quotes around the URL in Railway's variable settings. Just paste the URL directly.

   **Optional:**
   - `TARGET_URL`: URL of the web page to stream (default: `https://www.google.com`)
     - No quotes needed here either
   - `RESOLUTION`: Video resolution (default: `1920x1080`)
   - `FRAMERATE`: Frames per second (default: `10`)

3. Click **"Deploy"** to trigger a new deployment

**Example of correct variable values in Railway:**
- `RTMP_URL` = `rtmps://pump-prod-tg2x8veh.rtmp.livekit.cloud/x/gb292QFSLYsp` ✅
- `RTMP_URL` = `"rtmps://..."` ❌ (Don't add quotes)

### Step 4: Configure Shared Memory (Important)

Railway doesn't support `--shm-size` directly. We need to configure it via Railway's settings:

1. Go to your service settings
2. Add a custom start command or use the `railway.json` configuration (see below)

## 🔧 Method 2: Using Railway Configuration File

Create a `railway.json` file in your project root:

```json
{
  "$schema": "https://railway.app/railway.schema.json",
  "build": {
    "builder": "DOCKERFILE",
    "dockerfilePath": "Dockerfile"
  },
  "deploy": {
    "startCommand": "sh -c 'mount -t tmpfs -o size=2g tmpfs /dev/shm && /entrypoint.sh'",
    "restartPolicyType": "ON_FAILURE",
    "restartPolicyMaxRetries": 10
  }
}
```

**Note:** Railway may not support mounting tmpfs directly. See alternative solution below.

## 🛠️ Alternative: Modify Dockerfile for Railway

Since Railway may have limitations with shared memory, we can modify the approach. However, the current Dockerfile should work. If you encounter Firefox crashes, you may need to:

1. Reduce the resolution: `RESOLUTION=1280x720`
2. Reduce the framerate: `FRAMERATE=5`

## 📝 Railway-Specific Configuration

### Using railway.toml (Alternative)

Create a `railway.toml` file:

```toml
[build]
builder = "DOCKERFILE"
dockerfilePath = "Dockerfile"

[deploy]
startCommand = "/entrypoint.sh"
healthcheckPath = "/"
healthcheckTimeout = 100
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10
```

### Environment Variables in Railway

Railway allows you to set environment variables in three ways:

1. **Dashboard UI**: Go to Variables tab → Add variable
2. **railway.toml**: Add `[variables]` section
3. **Railway CLI**: Use `railway variables set KEY=value`

Example `railway.toml` with variables:

```toml
[variables]
RTMP_URL = "rtmps://your-server.com/stream/key"
TARGET_URL = "https://example.com"
RESOLUTION = "1920x1080"
FRAMERATE = "10"
```

## 🚀 Quick Deploy Steps

1. **Install Railway CLI** (optional but recommended):
   ```bash
   npm i -g @railway/cli
   railway login
   ```

2. **Initialize Railway project**:
   ```bash
   railway init
   ```

3. **Set environment variables**:
   ```bash
   railway variables set RTMP_URL="rtmps://your-server.com/stream/key"
   railway variables set TARGET_URL="https://example.com"
   ```

4. **Deploy**:
   ```bash
   railway up
   ```

Or simply push to GitHub if connected, and Railway will auto-deploy.

## 📊 Monitoring Your Deployment

### View Logs

1. **Via Dashboard**: Go to your service → Click on "View Logs"
2. **Via CLI**:
   ```bash
   railway logs
   ```

### Check Deployment Status

- Green dot = Running
- Yellow dot = Building/Deploying
- Red dot = Failed

## ⚠️ Important Notes for Railway

1. **Shared Memory**: Railway may have limitations. If Firefox crashes, try:
   - Lower resolution: `RESOLUTION=1280x720`
   - Lower framerate: `FRAMERATE=5`

2. **Resource Limits**: Railway free tier has resource limits. Consider upgrading if you need more resources.

3. **No HTTP Port Required**: This container doesn't expose an HTTP port, which is fine for Railway. The container just streams to RTMP.

4. **Continuous Deployment**: Railway auto-deploys on every push to your main branch.

5. **Build Time**: First build may take 5-10 minutes due to package installation.

## 🐛 Troubleshooting

### Build Fails

- Check Railway logs for specific errors
- Verify Dockerfile syntax
- Ensure all files are committed to Git

### Container Crashes

- Check logs: `railway logs` or via dashboard
- Verify `RTMP_URL` is set correctly
- Check if RTMP server is accessible from Railway's network

### Firefox Not Starting

- Check logs for Firefox errors
- Try reducing resolution: `RESOLUTION=1280x720`
- Verify shared memory (may be limited on Railway)

### Stream Not Working

1. Verify RTMP URL is correct
2. Check Railway logs for FFmpeg errors
3. Test RTMP URL with another tool (OBS, FFmpeg)
4. Ensure RTMP server accepts connections from Railway's IPs
5. **Check for quotes in RTMP_URL**: If you see errors like `"rtmps://...: No such file or directory`, it means there are quotes around your RTMP_URL. Remove them in Railway's variable settings.

## 💰 Railway Pricing

- **Free Tier**: Limited resources, suitable for testing
- **Hobby Plan**: $5/month - Better for production
- **Pro Plan**: $20/month - More resources

For streaming workloads, consider the Hobby or Pro plan for better performance.

## 🔗 Useful Links

- [Railway Documentation](https://docs.railway.app/)
- [Railway Discord](https://discord.gg/railway)
- [Railway Status](https://status.railway.app/)

## 📄 Example railway.toml

Here's a complete example `railway.toml`:

```toml
[build]
builder = "DOCKERFILE"
dockerfilePath = "Dockerfile"

[deploy]
startCommand = "/entrypoint.sh"
restartPolicyType = "ON_FAILURE"
restartPolicyMaxRetries = 10

[variables]
# Set these in Railway dashboard instead for security
# RTMP_URL = "your-rtmp-url"
# TARGET_URL = "https://example.com"
```

