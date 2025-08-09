#!/usr/bin/env bash
set -euo pipefail

# Exiger root
if [[ $EUID -ne 0 ]]; then
  echo "Lance ce script avec sudo ou en root."
  exit 1
fi

# Variables
DEBIAN_FRONTEND=noninteractive
APP_USER="${SUDO_USER:-$(logname 2>/dev/null || echo root)}"
SYM_SRC_DIR="$(eval echo ~${APP_USER})"
BIN_DIR="/usr/local/bin"

echo "==> Mise à jour"
apt-get update -y
apt-get upgrade -y

echo "==> Outils de base"
apt-get install -y curl wget git unzip zip build-essential ca-certificates gnupg lsb-release

echo "==> Apache + PHP"
apt-get install -y apache2
# Choisis mod_php OU php-fpm. Ici mod_php pour coller à ton script initial.
apt-get install -y php-cli php-common php-mysql php-xml php-mbstring php-curl php-zip php-gd libapache2-mod-php
a2enmod php* >/dev/null || true
systemctl enable --now apache2

echo "==> MySQL Server/Client"
apt-get install -y mysql-server mysql-client
systemctl enable --now mysql

# Sécurisation interactive (tu peux automatiser si besoin)
echo "==> Pense à lancer : mysql_secure_installation"

echo "==> Composer (avec vérif de signature)"
EXPECTED_SIGNATURE="$(curl -fsSL https://composer.github.io/installer.sig)"
php -r "copy('https://getcomposer.org/installer','composer-setup.php');"
ACTUAL_SIGNATURE="$(php -r "echo hash_file('sha384','composer-setup.php');")"
if [ "$EXPECTED_SIGNATURE" != "$ACTUAL_SIGNATURE" ]; then
  >&2 echo 'ERREUR: signature Composer invalide'; rm -f composer-setup.php; exit 1
fi
php composer-setup.php --install-dir="$BIN_DIR" --filename=composer
rm -f composer-setup.php
composer --version

echo "==> Symfony CLI"
# Installateur officiel (place binaire dans ~/.symfony/bin/symfony pour l'utilisateur qui lance)
sudo -u "$APP_USER" bash -lc 'wget -qO- https://get.symfony.com/cli/installer | bash'
if [ -x "$SYM_SRC_DIR/.symfony/bin/symfony" ]; then
  install -m 0755 "$SYM_SRC_DIR/.symfony/bin/symfony" "$BIN_DIR/symfony"
elif compgen -G "$SYM_SRC_DIR/.symfony*/bin/symfony" > /dev/null; then
  install -m 0755 $(echo "$SYM_SRC_DIR"/.symfony*/bin/symfony) "$BIN_DIR/symfony"
fi
symfony -V || true

echo "==> Node.js LTS + npm (NodeSource)"
# Script officiel NodeSource (LTS)
curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt-get install -y nodejs
node -v
npm -v


echo "==> Redémarrage des services"
systemctl restart apache2
systemctl restart mysql

echo "Terminé ✅"



