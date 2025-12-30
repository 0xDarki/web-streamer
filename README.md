# Web Streamer

A Docker container to stream a web page to an RTMP/RTMPS server using Firefox and FFmpeg.

## 🚀 Quick Start

### Prerequisites

- Docker installed and configured
- A valid RTMP/RTMPS URL for streaming

### Basic Command

```bash
docker run -d --rm \
  --name mon-stream \
  --shm-size=2gb \
  -e TARGET_URL="https://example.com" \
  -e RTMP_URL="rtmps://your-rtmp-server.com/stream/key" \
  web-streamer
```

## 📋 Environment Variables

### Required

- **`RTMP_URL`** : Complete RTMP/RTMPS server URL (e.g., `rtmps://live-api-s.facebook.com:443/rtmp/CLE_STREAM`)
  - ⚠️ **This variable is required**, the container will stop if it's not defined

### Optional

- **`TARGET_URL`** : URL of the web page to stream (default: `https://www.google.com`)
- **`RESOLUTION`** : Video capture resolution (default: `1920x1080`)
- **`FRAMERATE`** : Frames per second (default: `10`)

## 📖 Usage Examples

### Example 1: Stream a custom web page

```bash
docker run -d --rm \
  --name stream-dashboard \
  --shm-size=2gb \
  -e TARGET_URL="https://liquid-website-production.up.railway.app/dashboard?stream=true" \
  -e RTMP_URL="rtmps://pump-prod-tg2x8veh.rtmp.livekit.cloud/x/gb292QFSLYsp" \
  web-streamer
```

### Example 2: Stream with custom resolution

```bash
docker run -d --rm \
  --name stream-hd \
  --shm-size=2gb \
  -e TARGET_URL="https://example.com" \
  -e RTMP_URL="rtmps://your-server.com/stream/key" \
  -e RESOLUTION="1280x720" \
  -e FRAMERATE="30" \
  web-streamer
```

### Example 3: Stream in interactive mode (for debugging)

```bash
docker run -it --rm \
  --name stream-debug \
  --shm-size=2gb \
  -e TARGET_URL="https://example.com" \
  -e RTMP_URL="rtmps://your-server.com/stream/key" \
  web-streamer
```

## 🔍 Monitoring and Logs

### View container logs

```bash
docker logs -f mon-stream
```

### Check if container is running

```bash
docker ps | grep web-streamer
```

### Stop the stream

```bash
docker stop mon-stream
```

## 🛠️ Building the Image

### On your local machine

```bash
# Clone or download the project
cd web-streamer

# Build the image
docker build -t web-streamer .
```

### On a VM (with DNS configuration)

See [DEPLOY.md](./DEPLOY.md) for complete deployment instructions.

**Quick summary:**

1. Configure Docker DNS (one time only):
   ```bash
   sudo ./configure-docker-dns.sh
   ```

2. Build the image:
   ```bash
   ./build.sh
   ```

## 📝 Important Notes

- **Shared Memory**: The container requires at least 2GB of shared memory (`--shm-size=2gb`) for Firefox
- **Resolution**: Default resolution is 1920x1080, you can modify it with `RESOLUTION`
- **Framerate**: Default framerate is 10 fps to save bandwidth
- **Audio**: Audio is captured if available, otherwise the stream will be video only
- **RTMP_URL**: Must be a valid and complete RTMP or RTMPS URL

## 🐛 Troubleshooting

### Container stops immediately

Check the logs:
```bash
docker logs mon-stream
```

Common causes:
- `RTMP_URL` undefined or invalid
- Network connection issue
- RTMP server unreachable

### Firefox doesn't start

Verify that shared memory is sufficient:
```bash
docker run --shm-size=2gb ...
```

### DNS resolution issues

On a VM, configure Docker DNS:
```bash
sudo ./configure-docker-dns.sh
```

### Stream doesn't work

1. Verify that the RTMP URL is correct and accessible
2. Check the logs: `docker logs -f mon-stream`
3. Test the RTMP connection with another tool (OBS, FFmpeg direct)

## 📚 Project Structure

- `Dockerfile`: Docker image definition
- `entrypoint.sh`: Container startup script
- `build.sh`: Script to build the image
- `deploy.sh`: Script to deploy on a VM
- `configure-docker-dns.sh`: Docker DNS configuration
- `commande_custom.txt`: Docker command example

## 🔗 Useful Links

- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)
- [Docker Documentation](https://docs.docker.com/)
- [RTMP Format](https://en.wikipedia.org/wiki/Real-Time_Messaging_Protocol)

## 📄 License

This project is provided as-is, without warranty.

