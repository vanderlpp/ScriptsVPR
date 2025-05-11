#!/bin/bash

# ┌───────────────────────────────────────────────────────────────┐
# │  Script de Instalação do CloudPanel + MariaDB 11.4 + SSL      │
# │  Compatível com: Ubuntu 24.04 LTS                             │
# │  Autor: Vander - ScriptsVPR                                   │
# └───────────────────────────────────────────────────────────────┘

set -e

# CONFIGURAÇÕES
DB_VERSION="11.4"
DOMAIN="painel.exemplo.com"  # <- ALTERE PARA SEU DOMÍNIO
EMAIL="admin@exemplo.com"    # <- ALTERE PARA SEU E-MAIL

# Verifica se está como root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script deve ser executado como root."
  exit 1
fi

# Atualiza o sistema
echo "🔄 Atualizando o sistema..."
apt update && apt upgrade -y

# Instala dependências
echo "📦 Instalando dependências..."
apt install -y curl gnupg2 software-properties-common ca-certificates lsb-release apt-transport-https sudo

# Adiciona repositório MariaDB
echo "🔧 Adicionando repositório do MariaDB ${DB_VERSION}..."
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="${DB_VERSION}"

# Instala MariaDB
echo "📦 Instalando MariaDB ${DB_VERSION}..."
DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server mariadb-client

# Inicia MariaDB
echo "🚀 Iniciando MariaDB..."
systemctl enable mariadb
systemctl start mariadb

# Instala CloudPanel
echo "🌐 Instalando CloudPanel..."
curl -sS https://installer.cloudpanel.io/ce/v2/install.sh | sudo bash

# Aguarda CloudPanel
echo "⏳ Aguardando CloudPanel iniciar (30 segundos)..."
sleep 30

# Mostra IP local
IP=$(hostname -I | awk '{print $1}')
echo "✅ CloudPanel instalado! Acesse via IP: https://$IP:8443"

# Solicita configuração de SSL
read -p "Deseja configurar SSL com Let's Encrypt para $DOMAIN? (s/n): " RESP
if [[ "$RESP" == "s" || "$RESP" == "S" ]]; then
  echo "🔐 Configurando SSL..."
  /usr/bin/cloudpanel cli ssl:enable --domains "$DOMAIN" --email "$EMAIL" --env production
  echo "✅ SSL configurado. Acesse: https://$DOMAIN:8443"
else
  echo "⚠️ Você pode configurar depois com:"
  echo "/usr/bin/cloudpanel cli ssl:enable --domains \"$DOMAIN\" --email \"$EMAIL\" --env production"
fi

echo "✅ Instalação concluída com sucesso!"
