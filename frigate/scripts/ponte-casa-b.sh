#!/usr/bin/env bash
# Transforma o mini PC T4 (Casa B, Linux) em ponte Tailscale para a rede das câmeras.
# Ele só repassa o tráfego: quase não usa CPU e não interfere no Hermes.
# Uso: sudo bash ponte-casa-b.sh            (detecta a rede local sozinho)
#      sudo bash ponte-casa-b.sh 192.168.0.0/24   (informando a rede)
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Rode com sudo: sudo bash $0"
  exit 1
fi

# Rede local = rota do kernel na interface que leva à internet.
IFACE=$(ip -4 route show default | awk '{print $5; exit}')
REDE=${1:-$(ip -4 route show dev "$IFACE" proto kernel | awk '{print $1; exit}')}
echo "Interface: $IFACE   Rede das câmeras: $REDE"
read -r -p "Está correto? [s/N] " resp
[ "$resp" = "s" ] || [ "$resp" = "S" ] || { echo "Cancelado. Informe a rede: sudo bash $0 192.168.X.0/24"; exit 1; }

if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi

# Repasse de pacotes (necessário para ser "subnet router").
cat > /etc/sysctl.d/99-tailscale.conf <<EOF
net.ipv4.ip_forward = 1
net.ipv6.conf.all.forwarding = 1
EOF
sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null

tailscale up --advertise-routes="$REDE"

echo
echo "Pronto. Agora, no painel https://login.tailscale.com/admin/machines :"
echo "  1. Abra esta máquina > Edit route settings > marque $REDE > Save"
echo "  2. Clique em 'Disable key expiry' para a ponte não desconectar sozinha"
