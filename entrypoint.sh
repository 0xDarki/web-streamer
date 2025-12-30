#!/bin/bash

# Ne pas quitter immédiatement en cas d'erreur pour certaines commandes
set +e

# Fonction pour logger avec timestamp
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Configuration
RESOLUTION="1920x1080"
FRAMERATE="10"
# URL de la page à streamer
TARGET_URL="${TARGET_URL:-https://www.google.com}"
# URL RTMPS (ex: rtmps://live-api-s.facebook.com:443/rtmp/CLE_STREAM)
RTMP_URL="${RTMP_URL}"
# Sélecteur CSS ou XPath du bouton play (optionnel)
PLAY_BUTTON_SELECTOR="${PLAY_BUTTON_SELECTOR:-}"
# Coordonnées X,Y du bouton play (optionnel, format: "x,y")
PLAY_BUTTON_COORDS="${PLAY_BUTTON_COORDS:-}"
# Délai avant de cliquer sur le bouton play (en secondes)
PLAY_BUTTON_DELAY="${PLAY_BUTTON_DELAY:-5}"

# Variables d'environnement pour Chromium
export DISPLAY=:99
export CHROMIUM_FLAGS="--no-sandbox --disable-gpu --disable-software-rasterizer --disable-dev-shm-usage"
export PATH=$PATH:/snap/bin

# Firefox ne nécessite pas snapd, on peut ignorer cette partie

log "Démarrage de Xvfb..."
# Nettoyer les anciens locks X11 si présents
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null || true
Xvfb :99 -ac -screen 0 ${RESOLUTION}x24 +extension RANDR &
XVFB_PID=$!
sleep 3

log "Vérification de Xvfb (PID: $XVFB_PID)..."
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
  log "ERREUR: Xvfb n'a pas démarré correctement!"
  exit 1
fi
log "Xvfb est actif"

log "Démarrage de PulseAudio (pour le son)..."
# PulseAudio en mode system pour éviter les warnings en root
pulseaudio --system -D --exit-idle-time=-1 --disallow-exit 2>/dev/null || \
pulseaudio -D --exit-idle-time=-1 --system=false --disallow-exit 2>/dev/null || true
sleep 2
# Créer un sink virtuel pour capturer l'audio du navigateur
pactl load-module module-null-sink sink_name=VirtualAudio sink_properties=device.description="VirtualAudio" 2>/dev/null || true
pactl set-default-sink VirtualAudio 2>/dev/null || true
# Configurer les permissions pour permettre l'accès au monitor
pactl set-sink-input-mute @DEFAULT_SINK@ false 2>/dev/null || true
# Vérifier que le monitor est accessible
if [ -e /dev/snd ]; then
  chmod 666 /dev/snd/* 2>/dev/null || true
fi
sleep 1

log "Lancement d'un gestionnaire de fenêtre simple..."
# xterm n'est pas critique, continuer même s'il échoue
xterm -geometry 1x1+0+0 -e "echo 'X11 ready'" 2>/dev/null &
XTERM_PID=$!
sleep 2
# Vérifier si xterm a crashé, mais continuer quand même
if ! kill -0 $XTERM_PID 2>/dev/null; then
  log "Avertissement: xterm s'est arrêté, mais ce n'est pas critique"
fi

# Vérifier que X11 fonctionne toujours
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
  log "ERREUR: Xvfb n'est plus accessible après xterm!"
  exit 1
fi
log "X11 est prêt"

set -e  # Réactiver la gestion d'erreur stricte après les initialisations

log "Préparation du profil Firefox..."
mkdir -p /tmp/firefox-profile
chmod 777 /tmp/firefox-profile

# Vérifier que RTMP_URL est défini et nettoyer les guillemets
if [ -z "$RTMP_URL" ]; then
  log "ERREUR: RTMP_URL n'est pas défini!"
  exit 1
fi

# Nettoyer les guillemets autour de RTMP_URL si présents
RTMP_URL=$(echo "$RTMP_URL" | sed 's/^"//;s/"$//' | sed "s/^'//;s/'$//")

log "Lancement de Firefox vers: $TARGET_URL"

# Détecter le binaire Firefox disponible
FIREFOX_CMD=""
log "Recherche de Firefox..."

if command -v firefox >/dev/null 2>&1; then
  log "Trouvé: firefox dans PATH"
  FIREFOX_CMD="firefox"
elif [ -f /usr/bin/firefox ]; then
  log "Trouvé: /usr/bin/firefox"
  FIREFOX_CMD="/usr/bin/firefox"
else
  log "ERREUR: Firefox non trouvé!"
  log "Recherche dans le système..."
  find /usr -name "*firefox*" -type f 2>/dev/null | head -10 || true
  exit 1
fi

log "Utilisation de: $FIREFOX_CMD"
$FIREFOX_CMD --version || log "Warning: Impossible de vérifier la version"

# Options Firefox pour le mode headless/kiosk
$FIREFOX_CMD \
  --profile /tmp/firefox-profile \
  --width ${RESOLUTION%x*} \
  --height ${RESOLUTION#*x} \
  --kiosk \
  "$TARGET_URL" 2>&1 | tee /tmp/firefox.log &

FIREFOX_PID=$!
log "Firefox lancé avec PID: $FIREFOX_PID"

# Fonction pour vérifier si Firefox est actif
check_firefox() {
  if ! kill -0 $FIREFOX_PID 2>/dev/null; then
    log "ERREUR: Firefox s'est arrêté!"
    log "Dernières lignes du log Firefox:"
    tail -20 /tmp/firefox.log 2>/dev/null || true
    return 1
  fi
  return 0
}

log "Attente du chargement de la page..."
for i in {1..20}; do
  sleep 1
  if ! check_firefox; then
    log "Firefox a crashé pendant l'attente!"
    exit 1
  fi
  if [ $((i % 5)) -eq 0 ]; then
    log "Attente... ($i/20)"
  fi
done

if ! check_firefox; then
  log "Firefox n'est pas actif après l'attente!"
  exit 1
fi

log "Firefox est actif"

# Fonction pour cliquer sur le bouton play
click_play_button() {
  if [ -n "$PLAY_BUTTON_COORDS" ]; then
    # Utiliser les coordonnées directement avec xdotool (méthode la plus fiable)
    log "Clic sur le bouton play aux coordonnées: $PLAY_BUTTON_COORDS"
    IFS=',' read -r X Y <<< "$PLAY_BUTTON_COORDS"
    # Activer la fenêtre Firefox d'abord
    xdotool search --name "Firefox" windowactivate --sync 2>/dev/null || true
    sleep 0.5
    # Déplacer la souris et cliquer
    xdotool mousemove --sync "$X" "$Y" click 1
    log "Clic effectué aux coordonnées ($X, $Y)"
    return 0
  elif [ -n "$PLAY_BUTTON_SELECTOR" ]; then
    # Utiliser un sélecteur CSS - injecter du JavaScript via la console Firefox
    log "Recherche du bouton play avec le sélecteur CSS: $PLAY_BUTTON_SELECTOR"
    
    # Activer la fenêtre Firefox
    xdotool search --name "Firefox" windowactivate --sync 2>/dev/null || true
    sleep 0.5
    
    # Ouvrir la console développeur (F12) et exécuter le script
    # Note: Cette méthode nécessite que la console soit accessible
    log "Tentative d'injection JavaScript via la console..."
    
    # Alternative: utiliser xdotool pour simuler un clic sur les coordonnées du bouton
    # Pour trouver les coordonnées, vous pouvez utiliser les outils de développement du navigateur
    log "Avertissement: Les sélecteurs CSS nécessitent les coordonnées du bouton"
    log "Pour une méthode plus fiable, utilisez PLAY_BUTTON_COORDS"
    log "Pour trouver les coordonnées:"
    log "  1. Ouvrez votre page dans un navigateur"
    log "  2. Faites un clic droit sur le bouton play > Inspecter"
    log "  3. Dans la console, exécutez:"
    log "     const btn = document.querySelector('$PLAY_BUTTON_SELECTOR');"
    log "     const rect = btn.getBoundingClientRect();"
    log "     console.log(rect.left + rect.width/2, rect.top + rect.height/2);"
    return 1
  else
    log "Aucun bouton play configuré, passage au stream"
    return 0
  fi
}

# Attendre un peu puis cliquer sur le bouton play si configuré
if [ -n "$PLAY_BUTTON_COORDS" ] || [ -n "$PLAY_BUTTON_SELECTOR" ]; then
  log "Attente de $PLAY_BUTTON_DELAY secondes pour que la page se charge complètement..."
  sleep "$PLAY_BUTTON_DELAY"
  
  # Essayer plusieurs fois de cliquer (au cas où la page met du temps à charger)
  CLICK_SUCCESS=false
  for attempt in {1..5}; do
    log "Tentative $attempt/5 de clic sur le bouton play..."
    if click_play_button; then
      log "✓ Clic sur le bouton play réussi"
      CLICK_SUCCESS=true
      sleep 3  # Attendre un peu après le clic pour que la musique démarre
      break
    else
      if [ $attempt -lt 5 ]; then
        log "Échec du clic, nouvelle tentative dans 3 secondes..."
        sleep 3
      else
        log "⚠️  Impossible de cliquer sur le bouton play après 5 tentatives"
        log "Le stream continuera sans activer la musique"
      fi
    fi
  done
  
  if [ "$CLICK_SUCCESS" = "true" ]; then
    log "Musique activée, démarrage du stream..."
  fi
fi

log "Démarrage du stream..."

# Fonction de surveillance de Firefox en arrière-plan
monitor_firefox() {
  while true; do
    sleep 5
    if ! check_firefox; then
      log "Firefox a crashé, arrêt du stream..."
      pkill -f ffmpeg || true
      exit 1
    fi
  done
}

# Démarrer la surveillance en arrière-plan
monitor_firefox &
MONITOR_PID=$!

log "Lancement du stream FFmpeg vers: $RTMP_URL"
# Désactiver le trap ERR temporairement pour FFmpeg car il peut échouer normalement
set +e

# Vérifier si l'audio est disponible
USE_AUDIO=false
if pactl list sinks 2>/dev/null | grep -q "VirtualAudio"; then
  # Essayer d'utiliser l'audio
  if [ -e /dev/snd ] || [ -d /dev/snd ]; then
    USE_AUDIO=true
    log "Audio disponible, inclusion dans le stream"
  else
    log "Avertissement: Audio non disponible, stream vidéo uniquement"
  fi
else
  log "Avertissement: VirtualAudio non trouvé, stream vidéo uniquement"
fi

# Construire et exécuter la commande FFmpeg
# Vérifier que X11 est accessible avant de commencer
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
  log "ERREUR: X11 n'est pas accessible pour FFmpeg!"
  exit 1
fi

log "Vérification de la connexion RTMP..."
# Tester la connexion RTMP (timeout de 5 secondes)
if ! timeout 5 bash -c "echo > /dev/tcp/$(echo $RTMP_URL | sed -E 's|^rtmps?://([^:/]+).*|\1|')/443" 2>/dev/null; then
  log "Avertissement: Impossible de tester la connexion RTMP, continuation..."
fi

if [ "$USE_AUDIO" = "true" ]; then
  # Avec audio
  log "Démarrage FFmpeg avec audio..."
  ffmpeg -loglevel error -stats \
    -f x11grab -video_size $RESOLUTION -framerate $FRAMERATE -i :99.0+0,0 \
    -probesize 20M -analyzeduration 20M \
    -f pulse -i VirtualAudio.monitor -ac 2 \
    -c:v libx264 -preset ultrafast -tune zerolatency \
    -b:v 2500k -maxrate 2500k -bufsize 5000k \
    -pix_fmt yuv420p -g 60 -keyint_min 60 \
    -threads 0 -x264-params "threads=auto" \
    -c:a aac -b:a 128k -ar 44100 -ac 2 \
    -af "aresample=async=1" \
    -fflags +genpts \
    -flags +global_header \
    -f flv "$RTMP_URL"
else
  # Sans audio (vidéo uniquement)
  log "Démarrage FFmpeg sans audio..."
  ffmpeg -loglevel error -stats \
    -f x11grab -video_size $RESOLUTION -framerate $FRAMERATE -i :99.0+0,0 \
    -probesize 20M -analyzeduration 20M \
    -c:v libx264 -preset ultrafast -tune zerolatency \
    -b:v 2500k -maxrate 2500k -bufsize 5000k \
    -pix_fmt yuv420p -g 60 -keyint_min 60 \
    -threads 0 -x264-params "threads=auto" \
    -an \
    -fflags +genpts \
    -flags +global_header \
    -f flv "$RTMP_URL"
fi

# Capturer le code de sortie de FFmpeg (en tenant compte du pipe)
FFMPEG_EXIT=${PIPESTATUS[0]}
set -e

if [ $FFMPEG_EXIT -ne 0 ]; then
  log "FFmpeg a échoué avec le code de sortie: $FFMPEG_EXIT"
  log "Vérification de l'URL RTMP: $RTMP_URL"
  log "Vérification de X11..."
  xdpyinfo -display :99 >/dev/null 2>&1 && log "X11 est accessible" || log "X11 n'est pas accessible"
  log "Nettoyage des processus..."
  kill $MONITOR_PID 2>/dev/null || true
  kill $FIREFOX_PID 2>/dev/null || true
  kill $XVFB_PID 2>/dev/null || true
  pkill -f ffmpeg 2>/dev/null || true
  log "Arrêt du conteneur"
  exit 1
fi

log "Stream terminé normalement"

# Nettoyer
kill $MONITOR_PID 2>/dev/null || true

