#!/bin/bash

# ┌────────────────────────────────────────────────────────────────────┐
# │ Script de Instalação do CloudPanel + MariaDB 11.4 + SSL + Proxmox │
# │ Compatível com: Ubuntu 24.04 LTS                                   │
# │ Autor: Vander - ScriptsVPR                                         │
# └────────────────────────────────────────────────────────────────────┘

set -e

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

# Se não houver domínio/email, perguntar
if [[ -z "$DOMAIN" ]]; then
  read -rp "🌐 Informe o domínio que será usado para SSL (ex: painel.seudominio.com): " DOMAIN
fi

if [[ -z "$EMAIL" ]]; then
  read -rp "📧 Informe o e-mail para Let's Encrypt (ex: admin@seudominio.com): " EMAIL
fi

# Validação simples
if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
  echo "❌ Domínio ou e-mail não podem estar vazios. Encerrando."
  exit 1
fi

if [ "$EUID" -ne 0 ]; then
  echo "❌ Este script deve ser executado como root."
  exit 1
fi

# Função: Finaliza ou remove serviços conflitantes
limpar_portas() {
  echo "⚠️  Verificando serviços que usam as portas 80, 443 e 3306..."

  SERVICOS=("apache2" "nginx" "mysql" "mariadb")

  for SVC in "${SERVICOS[@]}"; do
    if systemctl is-active --quiet "$SVC"; then
      echo "🔻 Serviço detectado: $SVC → parando..."
      systemctl stop "$SVC"
      systemctl disable "$SVC"
      echo "🧹 Removendo pacote $SVC..."
      apt remove -y "$SVC" || true
    fi
  done

  CONFLITOS=$(lsof -i :80 -i :443 -i :3306 || true)
  if [[ -n "$CONFLITOS" ]]; then
    echo "❌ Ainda há processos nas portas. Encerrando diretamente..."
    lsof -t -i :80 -i :443 -i :3306 | xargs -r kill -9
  fi

  echo "✅ Portas 80, 443 e 3306 estão livres."
}

echo "📡 Instalando qemu-guest-agent para integração com Proxmox VE..."
apt update
apt install -y qemu-guest-agent
systemctl start qemu-guest-agent
systemctl enable qemu-guest-agent

echo "🔄 Atualizando o sistema..."
apt upgrade -y

limpar_portas

echo "📦 Instalando dependências..."
apt install -y curl gnupg2 software-properties-common ca-certificates lsb-release apt-transport-https sudo

echo "🔧 Adicionando repositório do MariaDB ${DB_VERSION}..."
curl -LsS https://r.mariadb.com/downloads/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version="${DB_VERSION}"

echo "📦 Instalando MariaDB ${DB_VERSION}..."
DEBIAN_FRONTEND=noninteractive apt install -y mariadb-server mariadb-client

echo "🚀 Iniciando MariaDB..."
systemctl enable mariadb
systemctl start mariadb

echo "🌐 Instalando CloudPanel..."
curl -sS https://installer.cloudpanel.io/ce/v2/install.sh | sudo bash

echo "⏳ Aguardando CloudPanel iniciar (30 segundos)..."
sleep 30

IP=$(hostname -I | awk '{print $1}')
echo "✅ CloudPanel instalado! Acesse via IP: https://$IP:8443"

echo "🔐 Configurando SSL com Let's Encrypt para o domínio $DOMAIN..."
/usr/bin/cloudpanel cli ssl:enable --domains "$DOMAIN" --email "$EMAIL" --env production
echo "✅ SSL configurado com sucesso! Acesse: https://$DOMAIN:8443"

echo "🎉 Instalação finalizada com sucesso!"
