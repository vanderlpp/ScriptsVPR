#!/bin/bash

set -e

# CONFIGURAÇÕES
DB_VERSION="11.4"
DOMAIN="painel.exemplo.com"  # Altere para o domínio real
EMAIL="admin@exemplo.com"    # Altere para seu e-mail (usado no Let's Encrypt)

# Verifica se está como root
if [ "$EUID" -ne 0 ]; then
  echo "Este script deve ser executado como root."
  exit 1
fi

# Atualiza o sistema
echo "🔄 Atualizando o sistema..."
apt update && apt upgrade -y

# Instala dependências básicas
echo "📦 Instalando dependências básicas..."
apt install -y curl gnupg2 software-properties-common ca-certificates lsb-release apt-transport-https

# Adiciona repositório do MariaDB 11.4
echo "🔧 Adicionando repositório do MariaDB ${DB_VERSION}..."
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="${DB_VERSION}"

# Instala MariaDB
echo "📦 Instalando MariaDB ${DB_VERSION}..."
DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server mariadb-client

# Verifica se MariaDB está rodando
echo "🚀 Iniciando e habilitando MariaDB..."
systemctl enable mariadb
systemctl start mariadb

# Instala CloudPanel
echo "🌐 Instalando CloudPanel..."
curl -sS https://installer.cloudpanel.io/ce/v2/install.sh | sudo bash

# Aguarda o CloudPanel iniciar
echo "⏳ Aguardando CloudPanel iniciar (30 segundos)..."
sleep 30

# Obtém IP do servidor
IP=$(hostname -I | awk '{print $1}')

echo "🌐 CloudPanel instalado. Acesse via IP: https://$IP:8443 ou configure seu domínio."

# Configura Let's Encrypt SSL (requer domínio apontando corretamente para o IP)
read -p "Deseja configurar SSL com Let's Encrypt agora? (s/n): " RESP
if [[ "$RESP" == "s" || "$RESP" == "S" ]]; then
  echo "🔐 Configurando SSL para $DOMAIN..."
  /usr/bin/cloudpanel cli ssl:enable --domains "$DOMAIN" --email "$EMAIL" --env production

  echo "✅ SSL configurado! Acesse: https://$DOMAIN:8443"
else
  echo "⚠️ SSL não configurado. Você pode fazer isso mais tarde com:"
  echo "/usr/bin/cloudpanel cli ssl:enable --domains \"$DOMAIN\" --email \"$EMAIL\" --env production"
fi

echo "✅ Instalação finalizada com sucesso!"
