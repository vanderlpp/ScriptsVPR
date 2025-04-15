#!/bin/bash

set -e

# --- CONFIGURACAO ---
SIGNALING_DIR="/opt/signaling"
SIGNALING_BIN="/usr/local/bin/signaling"
SIGNALING_USER="www-data"
CONFIG_PATH="/var/www/nextcloud/resources/config/signaling.yml"
SECRET_PATH="/var/www/nextcloud/resources/config/signaling_secret"
SERVICE_FILE="/etc/systemd/system/signaling.service"

# --- INSTALAR DEPENDENCIAS ---
echo "[1/7] Instalando dependências..."
apt update && apt install -y git curl build-essential nodejs npm

# --- ATUALIZAR NODE ---
echo "[2/7] Verificando versão do Node.js..."
NODE_VERSION=$(node -v 2>/dev/null || echo "v0.0.0")
if [[ "$NODE_VERSION" < "v16" ]]; then
  npm install -g n
  n stable
fi

# --- CLONAR REPOSITORIO ---
echo "[3/7] Clonando Signaling Server..."
rm -rf "$SIGNALING_DIR"
git config --global url."https://github.com/".insteadOf git@github.com:
git config --global url."https://".insteadOf git://
git clone https://github.com/nextcloud-releases/signaling.git "$SIGNALING_DIR"
cd "$SIGNALING_DIR"
npm install
npm run build

# --- CRIAR BINARIO ---
echo "[4/7] Instalando sinalizador..."
echo -e "#!/bin/bash\nexec /usr/bin/node $SIGNALING_DIR/dist/server.js --config $CONFIG_PATH" > "$SIGNALING_BIN"
chmod +x "$SIGNALING_BIN"

# --- CONFIGURAR YAML ---
echo "[5/7] Configurando YAML..."
mkdir -p "$(dirname "$CONFIG_PATH")"
if [[ ! -f "$SECRET_PATH" ]]; then
  echo "$(openssl rand -hex 32)" > "$SECRET_PATH"
fi
SECRET=$(cat "$SECRET_PATH")

cat > "$CONFIG_PATH" <<EOF
logging:
  level: info

server:
  port: 8080

sharedSecret: "$SECRET"

cors:
  origins:
    - "*"
EOF
chown -R $SIGNALING_USER:$SIGNALING_USER "$(dirname "$CONFIG_PATH")"

# --- CRIAR SERVICO SYSTEMD ---
echo "[6/7] Criando serviço systemd..."
cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Nextcloud Talk Signaling Server
After=network.target

[Service]
ExecStart=$SIGNALING_BIN
Restart=always
User=$SIGNALING_USER
Group=$SIGNALING_USER
Environment=NODE_ENV=production
WorkingDirectory=$SIGNALING_DIR

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now signaling.service

# --- TESTE FINAL ---
echo "[7/7] Verificação final..."
sleep 2
STATUS=$(curl -sk https://localhost:8080/status || echo "ERRO")
if [[ "$STATUS" == *"ok"* ]]; then
  echo "✅ Signaling Server instalado e funcionando em https://localhost:8080/status"
else
  echo "⚠️  Signaling Server instalado, mas não respondeu corretamente. Verifique com: journalctl -u signaling.service -f"
fi
