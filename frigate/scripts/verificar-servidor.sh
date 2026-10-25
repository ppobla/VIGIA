#!/usr/bin/env bash
# Verifica se o PC (i5) está pronto para rodar o Frigate. Não altera nada.
# Uso: bash scripts/verificar-servidor.sh

ok()   { echo "  [OK]    $*"; }
falha(){ echo "  [FALHA] $*"; }
aviso(){ echo "  [AVISO] $*"; }

echo "== Processador =="
grep -m1 "model name" /proc/cpuinfo | sed 's/.*: /  /'
if grep -qw avx2 /proc/cpuinfo; then ok "AVX2 presente (exigido pelo Frigate)"; else falha "sem AVX2: o Frigate não roda neste PC"; fi

echo "== Memória e disco =="
free -h | awk '/^Mem:/ {print "  RAM total: " $2}'
df -h / | awk 'NR==2 {print "  Disco livre em /: " $4}'

echo "== GPU Intel (decodificação de vídeo) =="
if [ -e /dev/dri/renderD128 ]; then ok "/dev/dri/renderD128 encontrado"; else aviso "/dev/dri/renderD128 não existe: remova a seção devices do docker-compose.yml e a linha hwaccel_args do config.yml"; fi

echo "== Docker =="
if command -v docker >/dev/null; then ok "$(docker --version)"; else falha "Docker não instalado (veja o README)"; fi
if docker compose version >/dev/null 2>&1; then ok "docker compose disponível"; else falha "docker compose não encontrado"; fi

echo "== Tailscale =="
if command -v tailscale >/dev/null; then
  ok "tailscale instalado — IP: $(tailscale ip -4 2>/dev/null || echo 'não conectado')"
else
  aviso "Tailscale não instalado (necessário para a Casa B e para o acesso remoto)"
fi

echo "== Rede local deste PC =="
ip -4 route | awk '/proto kernel/ && !/docker|br-|tailscale/ {print "  " $1 " (" $3 ")"}'
echo "  A rede da Casa B precisa ser DIFERENTE desta (ex.: 192.168.1.0/24 aqui e 192.168.0.0/24 lá)."

echo "== Arquivo .env =="
cd "$(dirname "$0")/.." || exit 1
if [ -f .env ]; then
  if grep -q "troque-me" .env; then aviso ".env ainda tem senhas de exemplo (troque-me)"; else ok ".env preenchido"; fi
else
  falha ".env não existe: rode  cp .env.example .env  e preencha"
fi
