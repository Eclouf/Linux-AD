#!/bin/bash

# Interactive script to join a Linux machine to an Active Directory domain
# and optionally configure an automatic CIFS share mount.

DIR_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHEMIN_RESSOURCES="${DIR_SCRIPT}/ressources"

# Check root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root or with sudo."
  exit 1
fi

# Logging defaults (can be overridden by join_ad.conf)
LOG_ENABLED="no"
LOG_FILE="/var/log/join_ad.log"

# Charger les fonctions de backup
source $CHEMIN_RESSOURCES/backup.sh

# Charger les fonctions de fix_apt
source $CHEMIN_RESSOURCES/fix_apt.sh

#trap 'echo "An error occurred, restoring configuration files..."; restore_backup; exit 1' ERR

if [ $# -lt 1 ]; then

    if [ "$LOG_ENABLED" = "yes" ]; then
    LOG_DIR="$(dirname "$LOG_FILE")"
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    touch "$LOG_FILE" 2>/dev/null || true
    chmod 600 "$LOG_FILE" 2>/dev/null || true
    exec > >(tee -a "$LOG_FILE") 2>&1
    fi

    read -p "Domain name (e.g. mondomaine.local): " DOMAIN
    DOMAIN=${DOMAIN:-mondomaine.local}

    read -p "AD user with rights to join the domain (e.g. Administrateur): " AD_USER
    AD_USER=${AD_USER:-Administrateur}

    read -p "Domain controller IP address (DNS server): " DNS_SERVER
    DNS_SERVER=${DNS_SERVER:-192.168.0.1}

    echo
    read -p "Do you want to configure an automatic CIFS share mount? [y/N]: " ENABLE_SHARE
    ENABLE_SHARE=${ENABLE_SHARE:-N}

    if [[ "$ENABLE_SHARE" =~ ^[Yy]$ ]]; then
    read -p "File server name or IP (e.g. filesrv01): " SHARE_SERVER
    SHARE_SERVER=${SHARE_SERVER:-filesrv01}

    read -p "Share name (e.g. Services): " SHARE_NAME
    SHARE_NAME=${SHARE_NAME:-Services}

    read -p "Local mount point (e.g. /mnt/services): " MOUNT_POINT
    MOUNT_POINT=${MOUNT_POINT:-/mnt/services}

    read -p "Domain for share authentication (default: $DOMAIN): " SHARE_DOMAIN
    SHARE_DOMAIN=${SHARE_DOMAIN:-$DOMAIN}

    read -p "User for share access (default: $AD_USER): " SHARE_USER
    SHARE_USER=${SHARE_USER:-$AD_USER}
    fi

    read -p "Do you want to configure an automatic AD sudo group? [y/N]: " ENABLE_SUDO
    ENABLE_SUDO=${ENABLE_SUDO:-N}

    if [[ "$ENABLE_SUDO" =~ ^[Yy]$ ]]; then
    read -p "AD sudo group name (e.g. admin): " SUDO_GROUP
    SUDO_GROUP=${SUDO_GROUP:-admin}
    fi
else
  # Si fichier config fourni en argument, on le charge
  CONFIG_FILE="$1"
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    echo "Configuration chargée depuis $CONFIG_FILE"
  else
    echo "Fichier de configuration $CONFIG_FILE non trouvé, arrêt."
    exit 1
  fi
fi


echo
echo "Updating packages..."
if ! apt update -y; then
  echo "apt update failed, trying to fix apt sources..."
  fix_package_sources
  apt update -y
fi
apt upgrade -y

echo "Installing required packages..."
apt install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit cifs-utils libpam-mount

echo "Configuring DNS..."
#backup_file /etc/resolv.conf
echo -e "nameserver $DNS_SERVER\nsearch $DOMAIN" > /etc/resolv.conf

echo "Discovering domain..."
realm discover "$DOMAIN" || echo "Warning: realm discover failed, will still attempt join if needed."

echo "Joining domain (password for $AD_USER will be requested by realm)..."
realm join -U "$AD_USER" "$DOMAIN"

echo "Enabling automatic home directory creation at first login..."
#backup_file /usr/share/pam-configs/mkhomedir
cat <<EOF >/usr/share/pam-configs/mkhomedir
Name: Activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
  required pam_mkhomedir.so umask=0077 skel=/etc/skel
EOF

pam-auth-update --enable mkhomedir

echo "Restarting SSSD service..."
systemctl restart sssd

echo "Allowing domain users to log in..."
realm permit --all

echo "Enabling AD sys service..."
#systemctl enable adsysd.service
#systemctl start adsysd.service
#adsysd-cli refresh

if [[ "$ENABLE_SUDO" =~ ^[Yy]$ ]]; then
  echo "Configuring sudo group..."
  bash $CHEMIN_RESSOURCES/sudo_groupes.sh "$DOMAIN" "$SUDO_GROUP"
fi

if [[ "$ENABLE_SHARE" =~ ^[Yy]$ ]]; then
  echo "Configuring share..."
  bash $CHEMIN_RESSOURCES/share.sh "$SHARE_SERVER" "$SHARE_NAME"
fi

echo "Done. Test login with a domain user. If configured, the share will auto-mount at /mnt/\$USER using Kerberos."