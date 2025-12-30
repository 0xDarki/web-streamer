# Web Streamer

Un conteneur Docker pour streamer une page web vers un serveur RTMP/RTMPS en utilisant Firefox et FFmpeg.

## 🚀 Utilisation rapide

### Prérequis

- Docker installé et configuré
- Une URL RTMP/RTMPS valide pour le streaming

### Commande de base

```bash
docker run -d --rm \
  --name mon-stream \
  --shm-size=2gb \
  -e TARGET_URL="https://example.com" \
  -e RTMP_URL="rtmps://your-rtmp-server.com/stream/key" \
  web-streamer
```

## 📋 Variables d'environnement

### Obligatoires

- **`RTMP_URL`** : URL complète du serveur RTMP/RTMPS (ex: `rtmps://live-api-s.facebook.com:443/rtmp/CLE_STREAM`)
  - ⚠️ **Cette variable est obligatoire**, le conteneur s'arrêtera si elle n'est pas définie

### Optionnelles

- **`TARGET_URL`** : URL de la page web à streamer (défaut: `https://www.google.com`)
- **`RESOLUTION`** : Résolution de la capture vidéo (défaut: `1920x1080`)
- **`FRAMERATE`** : Fréquence d'images par seconde (défaut: `10`)

## 📖 Exemples d'utilisation

### Exemple 1 : Streamer une page web personnalisée

```bash
docker run -d --rm \
  --name stream-dashboard \
  --shm-size=2gb \
  -e TARGET_URL="https://liquid-website-production.up.railway.app/dashboard?stream=true" \
  -e RTMP_URL="rtmps://pump-prod-tg2x8veh.rtmp.livekit.cloud/x/gb292QFSLYsp" \
  web-streamer
```

### Exemple 2 : Streamer avec résolution personnalisée

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

### Exemple 3 : Streamer en mode interactif (pour debug)

```bash
docker run -it --rm \
  --name stream-debug \
  --shm-size=2gb \
  -e TARGET_URL="https://example.com" \
  -e RTMP_URL="rtmps://your-server.com/stream/key" \
  web-streamer
```

## 🔍 Vérification et logs

### Voir les logs du conteneur

```bash
docker logs -f mon-stream
```

### Vérifier que le conteneur tourne

```bash
docker ps | grep web-streamer
```

### Arrêter le stream

```bash
docker stop mon-stream
```

## 🛠️ Construction de l'image

### Sur votre machine locale

```bash
# Cloner ou télécharger le projet
cd web-streamer

# Construire l'image
docker build -t web-streamer .
```

### Sur une VM (avec configuration DNS)

Voir [DEPLOY.md](./DEPLOY.md) pour les instructions complètes de déploiement.

**Résumé rapide :**

1. Configurer le DNS Docker (une seule fois) :
   ```bash
   sudo ./configure-docker-dns.sh
   ```

2. Construire l'image :
   ```bash
   ./build.sh
   ```

## 📝 Notes importantes

- **Shared Memory** : Le conteneur nécessite au moins 2GB de shared memory (`--shm-size=2gb`) pour Firefox
- **Résolution** : La résolution par défaut est 1920x1080, vous pouvez la modifier avec `RESOLUTION`
- **Framerate** : Le framerate par défaut est 10 fps pour économiser la bande passante
- **Audio** : L'audio est capturé si disponible, sinon le stream sera vidéo uniquement
- **RTMP_URL** : Doit être une URL RTMP ou RTMPS valide et complète

## 🐛 Dépannage

### Le conteneur s'arrête immédiatement

Vérifiez les logs :
```bash
docker logs mon-stream
```

Causes communes :
- `RTMP_URL` non défini ou invalide
- Problème de connexion réseau
- Serveur RTMP inaccessible

### Firefox ne démarre pas

Vérifiez que le shared memory est suffisant :
```bash
docker run --shm-size=2gb ...
```

### Problèmes de résolution DNS

Sur une VM, configurez le DNS Docker :
```bash
sudo ./configure-docker-dns.sh
```

### Le stream ne fonctionne pas

1. Vérifiez que l'URL RTMP est correcte et accessible
2. Vérifiez les logs : `docker logs -f mon-stream`
3. Testez la connexion RTMP avec un autre outil (OBS, FFmpeg direct)

## 📚 Structure du projet

- `Dockerfile` : Définition de l'image Docker
- `entrypoint.sh` : Script de démarrage du conteneur
- `build.sh` : Script pour construire l'image
- `deploy.sh` : Script pour déployer sur une VM
- `configure-docker-dns.sh` : Configuration DNS Docker
- `commande_custom.txt` : Exemple de commande Docker

## 🔗 Liens utiles

- [Documentation FFmpeg](https://ffmpeg.org/documentation.html)
- [Documentation Docker](https://docs.docker.com/)
- [Format RTMP](https://en.wikipedia.org/wiki/Real-Time_Messaging_Protocol)

## 📄 Licence

Ce projet est fourni tel quel, sans garantie.

