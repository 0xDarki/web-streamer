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
# Forcer l'utilisation de l'audio même si VirtualAudio n'est pas détecté
FORCE_AUDIO="${FORCE_AUDIO:-false}"

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
# Nettoyer les anciennes instances de PulseAudio
pkill -9 pulseaudio 2>/dev/null || true
sleep 1

# Créer le répertoire pour les sockets PulseAudio
mkdir -p /tmp/pulse
chmod 755 /tmp/pulse
export PULSE_RUNTIME_PATH=/tmp/pulse
export PULSE_STATE_PATH=/tmp/pulse
export PULSE_SERVER=unix:/tmp/pulse/native

# Vérifier si on est root
if [ "$(id -u)" = "0" ]; then
  log "Exécution en root, démarrage de PulseAudio avec --fail=false..."
  # En root, utiliser --fail=false pour permettre le démarrage malgré l'avertissement
  pulseaudio -D --exit-idle-time=-1 --system=false --disallow-exit --fail=false 2>&1 | while IFS= read -r line; do
    log "PulseAudio: $line"
  done || {
    log "Tentative alternative: PulseAudio avec --start..."
    pulseaudio --start --exit-idle-time=-1 --disallow-exit --fail=false 2>&1 | while IFS= read -r line; do
      log "PulseAudio: $line"
    done || true
  }
else
  # Pas root, démarrage normal
  log "Démarrage de PulseAudio en mode user..."
  pulseaudio --start --exit-idle-time=-1 --disallow-exit 2>&1 | while IFS= read -r line; do
    log "PulseAudio: $line"
  done || {
    pulseaudio -D --exit-idle-time=-1 --system=false --disallow-exit 2>&1 | while IFS= read -r line; do
      log "PulseAudio: $line"
    done || true
  }
fi

sleep 3

# Vérifier que PulseAudio est actif
if ! pgrep -x pulseaudio >/dev/null; then
  log "Avertissement: PulseAudio n'a pas démarré, audio désactivé"
  log "Tentative de démarrage avec FORCE_AUDIO si activé..."
else
  log "✓ PulseAudio est actif (PID: $(pgrep -x pulseaudio))"
  
  # Désactiver le sink par défaut si nécessaire
  pactl unload-module module-suspend-on-idle 2>/dev/null || true
  
  # Créer un sink virtuel pour capturer l'audio du navigateur
  log "Création du sink virtuel VirtualAudio..."
  if pactl load-module module-null-sink sink_name=VirtualAudio sink_properties=device.description="VirtualAudio" 2>/dev/null; then
    log "✓ Sink VirtualAudio créé"
    sleep 1
    
    # Définir VirtualAudio comme sink par défaut
    if pactl set-default-sink VirtualAudio 2>/dev/null; then
      log "✓ VirtualAudio défini comme sink par défaut"
    else
      log "Avertissement: Impossible de définir VirtualAudio comme défaut"
    fi
    
    # Vérifier que le sink existe
    if pactl list sinks short | grep -q VirtualAudio; then
      log "✓ VirtualAudio vérifié et prêt"
    else
      log "Avertissement: VirtualAudio créé mais non détecté dans la liste"
    fi
  else
    log "Avertissement: Impossible de créer VirtualAudio, audio désactivé"
  fi
  
  # Configurer les permissions pour permettre l'accès au monitor
  pactl set-sink-input-mute @DEFAULT_SINK@ false 2>/dev/null || true
  
  # Vérifier que le monitor est accessible
  if [ -e /dev/snd ]; then
    chmod 666 /dev/snd/* 2>/dev/null || true
  fi
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

# Configurer Firefox pour utiliser PulseAudio
export PULSE_SERVER=unix:/tmp/pulse/native
export PULSE_RUNTIME_PATH=/tmp/pulse

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

# Vérifier que PulseAudio est actif
if ! pgrep -x pulseaudio >/dev/null; then
  log "Avertissement: PulseAudio n'est pas actif"
  if [ "$FORCE_AUDIO" = "true" ]; then
    log "⚠️  FORCE_AUDIO activé: tentative de redémarrage de PulseAudio..."
    
    # Utiliser --fail=false pour forcer le démarrage même en root
    if [ "$(id -u)" = "0" ]; then
      pulseaudio -D --exit-idle-time=-1 --system=false --disallow-exit --fail=false 2>/dev/null || \
      pulseaudio --start --exit-idle-time=-1 --disallow-exit --fail=false 2>/dev/null || true
    else
      pulseaudio --start --exit-idle-time=-1 --disallow-exit 2>/dev/null || \
      pulseaudio -D --exit-idle-time=-1 --system=false --disallow-exit 2>/dev/null || true
    fi
    
    sleep 3
    
    # Vérifier à nouveau
    if pgrep -x pulseaudio >/dev/null; then
      log "✓ PulseAudio redémarré avec succès"
    else
      log "⚠️  Impossible de redémarrer PulseAudio même avec FORCE_AUDIO"
    fi
    
    # Recréer VirtualAudio si nécessaire
    if pgrep -x pulseaudio >/dev/null; then
      pactl load-module module-null-sink sink_name=VirtualAudio sink_properties=device.description="VirtualAudio" 2>/dev/null || true
      pactl set-default-sink VirtualAudio 2>/dev/null || true
      sleep 1
    fi
  else
    log "Stream vidéo uniquement (utilisez FORCE_AUDIO=true pour forcer l'audio)"
  fi
else
  # Vérifier que VirtualAudio existe
  if pactl list sinks short 2>/dev/null | grep -q "VirtualAudio"; then
    log "VirtualAudio trouvé, vérification de l'accès au monitor..."
    
    # Vérifier que le monitor est accessible
    if [ -e /dev/snd ] || [ -d /dev/snd ]; then
      # Tester l'accès au monitor
      if pactl list sinks | grep -A 10 "VirtualAudio" | grep -q "Monitor"; then
        USE_AUDIO=true
        log "✓ Audio disponible, inclusion dans le stream"
      else
        log "Avertissement: Monitor VirtualAudio non accessible"
        if [ "$FORCE_AUDIO" = "true" ]; then
          log "⚠️  FORCE_AUDIO activé: utilisation de l'audio quand même"
          USE_AUDIO=true
        fi
      fi
    else
      log "Avertissement: /dev/snd non disponible"
      if [ "$FORCE_AUDIO" = "true" ]; then
        log "⚠️  FORCE_AUDIO activé: utilisation de l'audio quand même"
        USE_AUDIO=true
      fi
    fi
  else
    log "Avertissement: VirtualAudio non trouvé dans la liste des sinks"
    log "Liste des sinks disponibles:"
    pactl list sinks short 2>/dev/null | head -5 || log "Aucun sink disponible"
    
    if [ "$FORCE_AUDIO" = "true" ]; then
      log "⚠️  FORCE_AUDIO activé: tentative de création de VirtualAudio..."
      pactl load-module module-null-sink sink_name=VirtualAudio sink_properties=device.description="VirtualAudio" 2>/dev/null || true
      pactl set-default-sink VirtualAudio 2>/dev/null || true
      sleep 1
      if pactl list sinks short 2>/dev/null | grep -q "VirtualAudio"; then
        USE_AUDIO=true
        log "✓ VirtualAudio créé avec FORCE_AUDIO, utilisation de l'audio"
      else
        log "⚠️  Impossible de créer VirtualAudio même avec FORCE_AUDIO"
        USE_AUDIO=true  # Essayer quand même
        log "⚠️  Tentative d'utilisation de l'audio sans VirtualAudio (peut échouer)"
      fi
    fi
  fi
fi

# Résumé final
if [ "$USE_AUDIO" = "true" ]; then
  log "✓ Stream avec audio activé"
else
  log "⚠️  Stream vidéo uniquement (pas d'audio)"
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
  
  # Essayer d'abord avec VirtualAudio.monitor
  if pactl list sinks short 2>/dev/null | grep -q "VirtualAudio"; then
    AUDIO_INPUT="VirtualAudio.monitor"
    log "Utilisation de VirtualAudio.monitor pour l'audio"
  else
    # Si VirtualAudio n'existe pas mais FORCE_AUDIO est activé, essayer d'autres sources
    if [ "$FORCE_AUDIO" = "true" ]; then
      # Essayer de trouver un autre sink disponible
      DEFAULT_SINK=$(pactl list sinks short 2>/dev/null | head -1 | awk '{print $2}')
      if [ -n "$DEFAULT_SINK" ]; then
        AUDIO_INPUT="${DEFAULT_SINK}.monitor"
        log "⚠️  FORCE_AUDIO: utilisation de ${DEFAULT_SINK}.monitor"
      else
        # Dernière tentative: utiliser default
        AUDIO_INPUT="default"
        log "⚠️  FORCE_AUDIO: utilisation de 'default' comme source audio"
      fi
    else
      AUDIO_INPUT="VirtualAudio.monitor"
    fi
  fi
  
  ffmpeg -loglevel error -stats \
    -f x11grab -video_size $RESOLUTION -framerate $FRAMERATE -i :99.0+0,0 \
    -probesize 20M -analyzeduration 20M \
    -f pulse -i "$AUDIO_INPUT" -ac 2 \
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

