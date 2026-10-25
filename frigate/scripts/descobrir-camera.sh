#!/usr/bin/env bash
# Descobre a "família" de um DVR ou câmera IP pelas portas abertas e sugere o endereço para o Frigate.
# Com usuário e senha, também testa os endereços RTSP mais comuns (precisa do ffmpeg).
# Uso: bash scripts/descobrir-camera.sh 192.168.1.3
#      bash scripts/descobrir-camera.sh 192.168.1.3 admin SENHA
set -uo pipefail

if [ $# -lt 1 ]; then
  echo "Uso: $0 IP [usuario] [senha]"
  exit 1
fi
ip="$1"; usuario="${2:-}"; senha="${3:-}"

porta_aberta() { timeout 2 bash -c "</dev/tcp/$ip/$1" 2>/dev/null; }

echo "== Portas abertas em $ip =="
abertas=""
for p in 80 554 8000 8899 34567 37777; do
  if porta_aberta "$p"; then echo "  [ABERTA]  $p"; abertas="$abertas $p "; else echo "  [fechada] $p"; fi
done

echo "== Provável fabricante =="
if [[ "$abertas" == *" 34567 "* ]]; then
  echo "  Xiongmai (apps iCSee / XMEye; muitos DVRs Giga e Multi). Use no config.yml:"
  echo "    dvrip://USUARIO:SENHA@$ip:34567?channel=0&subtype=0   (principal; canal começa em 0)"
  echo "    dvrip://USUARIO:SENHA@$ip:34567?channel=0&subtype=1   (secundário)"
fi
if [[ "$abertas" == *" 37777 "* ]]; then
  echo "  Intelbras / Dahua:  rtsp://USUARIO:SENHA@$ip:554/cam/realmonitor?channel=1&subtype=1"
fi
if [[ "$abertas" == *" 8000 "* ]]; then
  echo "  Hikvision:          rtsp://USUARIO:SENHA@$ip:554/Streaming/Channels/102"
fi
if [[ "$abertas" != *" 34567 "* && "$abertas" != *" 37777 "* && "$abertas" != *" 8000 "* ]]; then
  echo "  Não identificado. Procure \"RTSP\" no manual ou use o app ONVIF Device Manager."
fi

if [ -z "$usuario" ]; then
  echo "Dica: passe usuário e senha para testar os endereços RTSP:  $0 $ip admin SENHA"
  exit 0
fi
if ! command -v ffprobe >/dev/null; then
  echo "ffprobe não encontrado: sudo apt install -y ffmpeg"
  exit 1
fi
if [[ "$abertas" != *" 554 "* ]]; then
  echo "Porta 554 (RTSP) fechada: o teste de RTSP foi pulado. Para Xiongmai, use o dvrip:// acima."
  exit 0
fi

echo "== Testando endereços RTSP (canal 1, stream secundário) =="
candidatos=(
  "rtsp://$ip:554/user=$usuario&password=$senha&channel=1&stream=1.sdp?real_stream"
  "rtsp://$usuario:$senha@$ip:554/cam/realmonitor?channel=1&subtype=1"
  "rtsp://$usuario:$senha@$ip:554/Streaming/Channels/102"
  "rtsp://$usuario:$senha@$ip:554/"
)
for url in "${candidatos[@]}"; do
  # Mostra o endereço sem a senha, para o terminal poder ser compartilhado.
  exibido="${url//$senha/SENHA}"
  if info=$(ffprobe -v error -rtsp_transport tcp -timeout 5000000 -select_streams v:0 \
      -show_entries stream=codec_name,width,height -of csv=p=0 "$url" 2>/dev/null) && [ -n "$info" ]; then
    echo "  [OK]    $exibido  ->  $info"
  else
    echo "  [falha] $exibido"
  fi
done
echo "Se o codec aparecer como hevc (H.265), mude para H.264 no app/menu do aparelho."
