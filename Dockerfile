FROM ubuntu:20.04

# Installation des dépendances (optimisées pour ARM64)
ENV DEBIAN_FRONTEND=noninteractive

# Installer les dépendances de base
RUN apt-get update --fix-missing || apt-get update && \
    apt-get install -y --no-install-recommends \
    xvfb \
    xterm \
    x11-utils \
    xdotool \
    ffmpeg \
    pulseaudio \
    pulseaudio-utils \
    socat \
    curl \
    wget \
    ca-certificates \
    fonts-liberation \
    libasound2 \
    libatk-bridge2.0-0 \
    libatk1.0-0 \
    libatspi2.0-0 \
    libcups2 \
    libdbus-1-3 \
    dbus-x11 \
    libdrm2 \
    libgbm1 \
    libgtk-3-0 \
    libnspr4 \
    libnss3 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxkbcommon0 \
    libxrandr2 \
    xdg-utils \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Installer Firefox directement (Ubuntu 20.04 a Firefox sans snap)
RUN echo "=== Installation de Firefox ===" && \
    apt-get update --fix-missing || apt-get update && \
    apt-get install -y --no-install-recommends firefox && \
    rm -rf /var/lib/apt/lists/* && \
    # Tester \
    firefox --version && \
    echo "✓ Firefox installé avec succès"

# Créer un répertoire pour le profil Firefox
RUN mkdir -p /tmp/firefox-profile

# Script de démarrage
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

