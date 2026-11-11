#!/bin/bash
# (Re)starts the manually-managed services that don't survive rebuilds or
# occasional crashes: the ffmpeg audio stream (port 8998) and the tiny HTTP
# server that serves audio.html/viewer.html (port 8999).
# Safe to run anytime - it only starts what isn't already running.
REPO=/workspaces/literate-octo-fortnight

echo "=== Service startup check ==="

# ffmpeg can disappear for reasons like a failed postCreateCommand during a rebuild,
# so repair it automatically here if needed.
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "[Repair] ffmpeg was not found; installing it now..."
  sudo apt-get update -qq && sudo apt-get install -y ffmpeg pulseaudio-utils
  if command -v ffmpeg >/dev/null 2>&1; then
    echo "[Repair complete] ffmpeg was installed successfully"
  else
    echo "[Error] ffmpeg installation failed"
  fi
fi

if ss -tln 2>/dev/null | grep -q ':8998 '; then
  echo "[OK] Audio stream (8998) is already running"
else
  nohup bash -c 'while true; do ffmpeg -fflags nobuffer -flags low_delay -f pulse -i auto_null.monitor -acodec libmp3lame -b:a 64k -ar 44100 -ac 2 -flush_packets 1 -f mp3 -listen 1 http://0.0.0.0:8998/stream.mp3; sleep 2; done' > /tmp/audio-stream.log 2>&1 &
  disown
  sleep 2
  if ss -tln 2>/dev/null | grep -q ':8998 '; then
    echo "[Started] Audio stream (8998) is now running"
  else
    echo "[Error] Audio stream (8998) failed to start. Check /tmp/audio-stream.log"
  fi
fi

if ss -tln 2>/dev/null | grep -q ':8999 '; then
  echo "[OK] Audio page server (8999) is already running"
else
  nohup python3 -m http.server 8999 --directory "$REPO" > /tmp/http8999.log 2>&1 &
  disown
  sleep 1
  if ss -tln 2>/dev/null | grep -q ':8999 '; then
    echo "[Started] Audio page server (8999) is now running"
  else
    echo "[Error] Audio page server (8999) failed to start. Check /tmp/http8999.log"
  fi
fi

echo ""
echo "Done. Open in a browser: https://<your-codespace-name>-8999.app.github.dev/audio.html"
