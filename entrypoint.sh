#!/bin/bash
set -e

# Ensure /data is owned by openclaw user and has restricted permissions
chown openclaw:openclaw /data 2>/dev/null || true
chmod 700 /data 2>/dev/null || true

# Ensure all state files on the volume are owned by the current openclaw user
# (UID may differ between container rebuilds)
if [ -d /data/.openclaw ]; then
  chown -R openclaw:openclaw /data/.openclaw 2>/dev/null || true
fi

# Persist Homebrew to Railway volume so it survives container rebuilds
BREW_VOLUME="/data/.linuxbrew"
BREW_SYSTEM="/home/openclaw/.linuxbrew"

if [ -d "$BREW_VOLUME" ]; then
  # Volume already has Homebrew — symlink back to expected location
  if [ ! -L "$BREW_SYSTEM" ]; then
    rm -rf "$BREW_SYSTEM"
    ln -sf "$BREW_VOLUME" "$BREW_SYSTEM"
    echo "[entrypoint] Restored Homebrew from volume symlink"
  fi
else
  # First boot — move Homebrew install to volume for persistence
  if [ -d "$BREW_SYSTEM" ] && [ ! -L "$BREW_SYSTEM" ]; then
    mv "$BREW_SYSTEM" "$BREW_VOLUME"
    ln -sf "$BREW_VOLUME" "$BREW_SYSTEM"
    echo "[entrypoint] Persisted Homebrew to volume on first boot"
  fi
fi

# Persist Playwright browsers to Railway volume so they survive container rebuilds
PW_VOLUME="/data/.cache/ms-playwright"
PW_SYSTEM="/home/openclaw/.cache/ms-playwright"

if [ -d "$PW_VOLUME" ] && [ -n "$(ls -A "$PW_VOLUME" 2>/dev/null)" ]; then
  # Volume already has Playwright browsers — symlink back
  if [ ! -L "$PW_SYSTEM" ]; then
    mkdir -p "$(dirname "$PW_SYSTEM")"
    rm -rf "$PW_SYSTEM"
    ln -sf "$PW_VOLUME" "$PW_SYSTEM"
    chown -h openclaw:openclaw "$PW_SYSTEM"
    echo "[entrypoint] Restored Playwright browsers from volume symlink"
  fi
elif [ -d "$PW_SYSTEM" ] && [ ! -L "$PW_SYSTEM" ] && [ -n "$(ls -A "$PW_SYSTEM" 2>/dev/null)" ]; then
  # First boot with browser installed — move to volume for persistence
  mkdir -p "$(dirname "$PW_VOLUME")"
  mv "$PW_SYSTEM" "$PW_VOLUME"
  ln -sf "$PW_VOLUME" "$PW_SYSTEM"
  chown -R openclaw:openclaw "$PW_VOLUME"
  chown -h openclaw:openclaw "$PW_SYSTEM"
  echo "[entrypoint] Persisted Playwright browsers to volume on first boot"
fi

# Set Playwright browser path for the runtime
export PLAYWRIGHT_BROWSERS_PATH="${PW_SYSTEM}"

exec gosu openclaw node src/server.js
