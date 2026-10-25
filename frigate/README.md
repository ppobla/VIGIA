# VIGIA com Frigate: guia de instalação

Objetivo: juntar as câmeras (DVRs e câmeras IP) das duas casas num só painel, com IA para
detectar pessoas, carros e motos e mandar alertas para o celular. Tudo roda nos seus
equipamentos, sem mensalidade e sem enviar imagens para a nuvem.

## Como fica a montagem

```
        CASA A                                          CASA B
 ┌──────────────────────────┐                ┌──────────────────────────┐
 │ PC i5 (servidor)         │                │ Mini PC T4 (Hermes)      │
 │  • Frigate (IA + gravação)│◄── Tailscale ──►│  • ponte Tailscale       │
 │  • Tailscale             │   (VPN grátis) │    (só repassa o vídeo)  │
 │        ▲                 │                │        ▲                 │
 │   DVR / câmeras IP       │                │   DVR / câmeras IP       │
 └──────────────────────────┘                └──────────────────────────┘
                 ▲
                 └──── Celular / notebook de qualquer lugar (app Tailscale)
```

**Por que cada equipamento tem esse papel:**

- **PC i5 4ª geração: servidor.** O Frigate exige processador com AVX2, e o i5 tem. Os 16 GB de
  RAM dão folga para mais de 10 câmeras com detecção no stream secundário.
- **Mini PC T4 (Atom Z8500): só a ponte.** O Atom não tem AVX2, então o Frigate não roda nele.
  Como ponte ele só repassa pacotes, quase não usa CPU e continua rodando o Hermes.
- **VPS: fica de fora.** Puxar todos os vídeos pela internet gasta o upload das casas, o
  disco da VPS é caro e a VPS não tem GPU. O Tailscale já resolve o acesso remoto.
- **DVRs: continuam gravando 24h.** O Frigate guarda só os eventos com IA, o que cabe no SSD
  de 120 GB.

> **Começando por uma casa:** o i5 e o T4 estão na mesma casa (Casa A), e a configuração já vem
> com a Casa B desativada. Nesta fase, pule o Passo 5. O T4 (Ubuntu) só entra quando a segunda
> casa for adicionada.

## Passo 1: preparar o PC i5 (Casa A)

1. Instale o **Ubuntu Server 24.04 LTS** no lugar do Windows (é o mesmo sistema do T4). O
   Frigate não tem suporte oficial no Windows, e no WSL a GPU do i5 não chega até ele.
   **Copie antes qualquer arquivo do Windows que queira guardar**: a instalação apaga o disco.
   Na instalação, marque **Install OpenSSH server** para acessar o i5 pelo T4 ou por outro PC.

   **Para manter o Windows**, instale o Ubuntu num SSD separado:
   - Desligue o PC e desconecte o cabo SATA do SSD do Windows. Assim o instalador não mexe nele.
   - Instale o Ubuntu no SSD novo e depois reconecte o SSD do Windows.
   - Na BIOS, coloque o SSD do Ubuntu em primeiro na ordem de boot. Para usar o Windows, escolha
     o disco no menu de boot (geralmente F8, F11 ou F12).
   - Também na BIOS, ative **Restore on AC Power Loss = Power On**. Assim o PC religa sozinho
     depois de uma queda de energia e o Frigate volta a funcionar sem você estar lá.
2. Instale o Docker e o Tailscale:

   ```bash
   curl -fsSL https://get.docker.com | sudo sh
   sudo usermod -aG docker $USER        # saia e entre de novo na sessão depois
   curl -fsSL https://tailscale.com/install.sh | sh
   sudo tailscale up --accept-routes    # abre um link: faça login com sua conta
   ```

3. Copie esta pasta `frigate/` para o PC (por exemplo, `git clone` do VIGIA) e verifique:

   ```bash
   cd VIGIA/frigate
   bash scripts/verificar-servidor.sh
   ```

## Passo 2: descobrir os endereços das câmeras

No DVR (menu **Rede**), confira se o **RTSP** está ativo (porta 554). Em cada canal, configure
o **stream secundário (extra)** em **H.264**, cerca de **640x360 ou 704x480** e **5 a 10 fps**.
É ele que a IA analisa.

| Marca | Principal | Secundário |
|---|---|---|
| Intelbras / Dahua (DVR ou câmera) | `/cam/realmonitor?channel=1&subtype=0` | `/cam/realmonitor?channel=1&subtype=1` |
| Hikvision (DVR ou câmera) | `/Streaming/Channels/101` | `/Streaming/Channels/102` |
| Outras marcas | procure "RTSP" no manual ou use o app **ONVIF Device Manager** | |

No DVR, `channel=N` (Intelbras/Dahua) ou `N01`/`N02` (Hikvision) é o número do canal.

Teste cada endereço antes de colocar no Frigate:

```bash
sudo apt install -y ffmpeg
bash scripts/testar-camera.sh "rtsp://admin:SENHA@192.168.1.100:554/cam/realmonitor?channel=1&subtype=1"
```

> Evite os caracteres `@ : / # ? &` na senha das câmeras: eles quebram o endereço RTSP.

## Passo 3: preencher a configuração

```bash
cp .env.example .env
nano .env                 # IPs, usuários e senhas dos DVRs e câmeras
nano config/config.yml    # uma entrada por câmera
```

O `config/config.yml` já vem com 5 câmeras de exemplo (3 na Casa A e 2 na Casa B). Para cada
câmera nova:

1. Em `go2rtc.streams`, crie `nome` (principal) e `nome_sub` (secundário).
2. Em `cameras`, copie um bloco existente e troque o nome.
3. Use nomes sem espaços e sem acentos, como `casa_a_portao` ou `casa_b_garagem`.

## Passo 4: subir o Frigate

```bash
docker compose up -d
docker compose logs frigate | grep -i password   # senha do usuário admin (1ª vez)
```

Abra `https://IP-DO-PC-i5:8971`. O navegador vai avisar sobre o certificado: é esperado, pode
continuar. Entre com `admin` e a senha do log, e troque a senha em **Configurações**.

## Passo 5: ponte na Casa B (mini PC T4)

Se o T4 roda Linux:

```bash
sudo bash ponte-casa-b.sh
```

Depois, no painel do Tailscale (https://login.tailscale.com/admin/machines), abra o T4:

1. Em **Edit route settings**, aprove a rede.
2. Clique em **Disable key expiry**.

**Atenção:** as duas casas precisam ter redes diferentes. Se as duas forem `192.168.1.x`, o
servidor não consegue alcançar a Casa B. O `verificar-servidor.sh` mostra a rede da Casa A. Se
for igual à da Casa B, troque a faixa do roteador de uma das casas (por exemplo,
`192.168.0.x` → `192.168.10.x`) ou peça ajuda para usar o modo de retransmissão.

Se o T4 roda Windows, instale o Tailscale para Windows. Avise antes, porque a configuração da
ponte é diferente.

## Passo 6: acesso pelo celular e notificações

1. Instale o app **Tailscale** no celular e entre com a mesma conta.
2. No servidor, publique o Frigate com HTTPS dentro da VPN:

   ```bash
   sudo tailscale serve --bg https+insecure://localhost:8971
   ```

   Antes, ative **HTTPS Certificates** em https://login.tailscale.com/admin/dns. O endereço
   passa a ser `https://NOME-DO-PC.SEU-TAILNET.ts.net`, sem aviso de certificado.
3. Abra esse endereço no celular e use **Adicionar à tela inicial** (vira um app).
4. No `config.yml`, descomente o bloco `notifications` e coloque seu e-mail. Reinicie com
   `docker compose restart`, e depois ative as notificações em **Configurações >
   Notificações**.

**Nunca** abra a porta 8971 (nem as do DVR) no roteador: DVRs expostos na internet são
invadidos com frequência. Todo acesso de fora passa pelo Tailscale.

## Capacidade esperada

| Item | Estimativa |
|---|---|
| Câmeras | mais de 10 com detecção no stream secundário a 5 fps |
| Detecção | OpenVINO na CPU, só onde há movimento |
| Upload da Casa B | ~0,5–1 Mbps por câmera (só stream secundário) |
| SSD de 120 GB | alertas por 7 dias e detecções por 3 dias; quando enche, o Frigate apaga o mais antigo |

Esses números são estimativas: o painel **Sistema** do Frigate mostra o uso real de CPU e o
tempo de inferência. Para guardar mais dias, coloque um HD de 1 TB e aponte o volume
`./storage` para ele no `docker-compose.yml`.

## Problemas comuns

| Sintoma | O que fazer |
|---|---|
| Câmera com tela verde ou erro de ffmpeg | Confira o endereço com `testar-camera.sh`. Se o stream for H.265, mude para H.264 no DVR |
| Erro no detector OpenVINO no log | No `config.yml`, troque o detector por `cpu1: { type: cpu }` (mais lento, mas funciona) |
| "Bus error" no log | Aumente `shm_size` no `docker-compose.yml` (ex.: `"1gb"`) |
| Câmeras da Casa B offline | Rode `tailscale status` no servidor e confira se a rota do T4 foi aprovada |
| Muitos alertas falsos (árvores, carros na rua) | Desenhe **zonas** e **máscaras** no painel (Configurações > Câmera) |

## Próximos passos (depois que estiver rodando)

- **Zonas**: alertar só para pessoa no portão ou no quintal, ignorando a calçada.
- **Reconhecimento facial e de placas**: já vem no Frigate e se ativa no `config.yml`.
- **Telegram ou Home Assistant**: alertas com foto e automações, como acender a luz quando
  detectar pessoa à noite.
- **Mais desempenho**: uma aceleradora de IA ou um mini PC N100 no futuro.

Documentação oficial: https://docs.frigate.video
