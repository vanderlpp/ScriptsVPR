#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────┐
# │ Script de Instalação do CloudPanel + MariaDB 11.4 + SSL + Proxmox │
# │ Compatível com: Ubuntu 24.04 LTS                                   │
# │ Autor: Vander - ScriptsVPR                                         │
# └────────────────────────────────────────────────────────────────────┘

set -e

# Valores padrão
DOMAIN=""
EMAIL=""
DB_VERSION="11.4"

# Lê parâmetros da linha de comando
for arg in "$@"; do
  case $arg in
    --domain=*)
      DOMAIN="${arg#*=}"
      shift
      ;;
    --email=*)
      EMAIL="${arg#*=}"
      shift
      ;;
  esac
done

# Verifica se os parâmetros foram fornecidos
if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
  echo "❌ Parâmetros obrigatórios não fornecidos."
  echo "   Uso correto:"
  echo "   bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/vanderlpp/ScriptsVPR/main/install-cloudpanel.sh)\" -- --domain=seu.dominio.com --email=seu@email.com"
  exit 1
fi

# Verifica se está como root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script deve ser executado como root."
  exit 1
fi

# Instala e ativa o agente do Proxmox VE
echo "📡 Instalando qemu-guest-agent para integração com Proxmox VE..."
apt update
apt install -y qemu-guest-agent
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent

# Atualiza o sistema
echo "🔄 Atualizando o sistema..."
apt upgrade -y

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

# Configura SSL
echo "🔐 Configurando SSL com Let's Encrypt para o domínio $DOMAIN..."
/usr/bin/cloudpanel cli ssl:enable --domains "$DOMAIN" --email "$EMAIL" --env production
echo "✅ SSL configurado com sucesso! Acesse: https://$DOMAIN:8443"

echo "✅ Instalação finalizada com sucesso!"
