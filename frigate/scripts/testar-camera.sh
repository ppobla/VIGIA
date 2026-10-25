#!/usr/bin/env bash
# Testa se um endereço RTSP responde e mostra resolução/codec. Precisa do ffmpeg (sudo apt install ffmpeg).
# Uso: bash scripts/testar-camera.sh "rtsp://admin:senha@192.168.1.100:554/cam/realmonitor?channel=1&subtype=1"
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Uso: $0 \"rtsp://usuario:senha@IP:554/caminho\""
  exit 1
fi

ffprobe -v error -rtsp_transport tcp -timeout 10000000 \
  -select_streams v:0 -show_entries stream=codec_name,width,height,avg_frame_rate \
  -of default=noprint_wrappers=1 "$1" && echo "[OK] câmera respondeu"
