#!/bin/bash

# Interactive script to join a Linux machine to an Active Directory domain
# and optionally configure an automatic CIFS share mount.

# Check root
if [ "$(id -u)" -ne 0 ]; then
  echo "Please run this script as root or with sudo."
  exit 1
fi

# Logging defaults (can be overridden by join_ad.conf)
LOG_ENABLED="no"
LOG_FILE="/var/log/join_ad.log"

if [ -f "./join_ad.conf" ]; then
  # shellcheck disable=SC1091
  . ./join_ad.conf
fi

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

  read -p "Credentials file path (default: /etc/samba/creds_share): " SHARE_CREDENTIALS_FILE
  SHARE_CREDENTIALS_FILE=${SHARE_CREDENTIALS_FILE:-/etc/samba/creds_share}
fi

echo
echo "Updating packages..."
apt update -y && apt upgrade -y

echo "Installing required packages..."
apt install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

echo "Configuring DNS..."
echo -e "nameserver $DNS_SERVER\nsearch $DOMAIN" > /etc/resolv.conf

echo "Discovering domain..."
realm discover "$DOMAIN"

echo "Joining domain (password for $AD_USER will be requested by realm)..."
realm join -U "$AD_USER" "$DOMAIN"

echo "Enabling automatic home directory creation at first login..."
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

if [[ "$ENABLE_SHARE" =~ ^[Yy]$ ]]; then
  echo "Configuring automatic mount for //$SHARE_SERVER/$SHARE_NAME ..."
  mkdir -p "$MOUNT_POINT"

  if [ ! -f "$SHARE_CREDENTIALS_FILE" ]; then
    echo "Creating credentials file for the share (password for $SHARE_DOMAIN\\$SHARE_USER will be requested)..."
    read -s -p "Password for $SHARE_DOMAIN\\$SHARE_USER: " SHARE_PASSWORD
    echo
    cat <<EOF >"$SHARE_CREDENTIALS_FILE"
username=$SHARE_DOMAIN\\$SHARE_USER
password=$SHARE_PASSWORD
domain=$SHARE_DOMAIN
EOF
    chmod 600 "$SHARE_CREDENTIALS_FILE"
  fi

  FSTAB_LINE="//$SHARE_SERVER/$SHARE_NAME  $MOUNT_POINT  cifs  credentials=$SHARE_CREDENTIALS_FILE,iocharset=utf8,uid=0,gid=0,file_mode=0644,dir_mode=0755  0  0"
  if ! grep -q "//$SHARE_SERVER/$SHARE_NAME" /etc/fstab; then
    echo "$FSTAB_LINE" >> /etc/fstab
  fi

  echo "Mounting share..."
  mount -a
fi

echo "Done. Test login with a domain user and, if configured, access the mounted share at $MOUNT_POINT."
