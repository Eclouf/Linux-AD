#!/bin/bash

# Vérifier si le script est lancé avec les droits root
if [ "$(id -u)" -ne 0 ]; then
  echo "Merci d'exécuter ce script en tant que root ou avec sudo"
  exit 1
fi

# Valeurs par défaut
DOMAIN="votre-domaine.local"
AD_USER="Administrateur"  # Utilisateur AD admin pour joindre le domaine
DNS_SERVER="IP_DU_CONTROLEUR_DE_DOMAINE"
ENABLE_SHARE_MOUNT="yes"  # mettre "yes" pour activer le montage auto du partage
SHARE_SERVER="serveur-fichiers"
SHARE_NAME="partage"
MOUNT_POINT="/mnt/partage"
SHARE_DOMAIN="$DOMAIN"
SHARE_USER="$AD_USER"
SHARE_CREDENTIALS_FILE="/etc/samba/creds_share"

# Options avancées (peuvent être surchargées par join_ad.conf)
ENABLE_REALM_AUTODETECT="no"
ENABLE_SSSD_TUNING="no"
USE_FQDN_LOGINS="no"        # no => login "user" au lieu de "user@domaine"
OVERRIDE_HOMEDIR="/home/%u"
ACCESS_PROVIDER="simple"    # par ex. "ad" ou "simple"

# Options de logging (peuvent être surchargées par join_ad.conf)
LOG_ENABLED="no"
LOG_FILE="/var/log/join_ad.log"

# Charger une éventuelle configuration externe
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

echo "Mise à jour des paquets..."
apt update -y && apt upgrade -y

echo "Installation des paquets nécessaires..."
apt install -y realmd sssd sssd-tools libnss-sss libpam-sss adcli samba-common-bin oddjob oddjob-mkhomedir packagekit

echo "Configuration du DNS…"
echo -e "nameserver $DNS_SERVER\nsearch $DOMAIN" > /etc/resolv.conf

if [ "$ENABLE_REALM_AUTODETECT" = "yes" ]; then
  echo "Tentative de détection automatique du domaine avec realm discover..."
  AUTO_REALM=$(realm discover 2>/dev/null | grep -i "realm-name" -m1 | awk '{print $2}')
  if [ -n "$AUTO_REALM" ]; then
    echo "Domaine détecté : $AUTO_REALM (remplace $DOMAIN)"
    DOMAIN="$AUTO_REALM"
  else
    echo "Aucun domaine détecté automatiquement, utilisation de la valeur configurée : $DOMAIN"
  fi
fi

echo "Découverte du domaine..."
realm discover "$DOMAIN"

echo "Joindre le domaine (mot de passe demandé)..."
realm join -U $AD_USER $DOMAIN

echo "Activer création automatique du dossier home à la première connexion utilisateur..."
cat <<EOF >/usr/share/pam-configs/mkhomedir
Name: Activate mkhomedir
Default: yes
Priority: 900
Session-Type: Additional
Session:
  required pam_mkhomedir.so umask=0077 skel=/etc/skel
EOF

pam-auth-update --enable mkhomedir

echo "Redémarrage du service SSSD..."
systemctl restart sssd

echo "Ajout des permissions au domaine pour connexion..."
realm permit --all

if [ "$ENABLE_SSSD_TUNING" = "yes" ]; then
  echo "Configuration avancée de SSSD (sauvegarde des fichiers avant modification)..."

  if [ -f /etc/sssd/sssd.conf ]; then
    cp /etc/sssd/sssd.conf "/etc/sssd/sssd.conf.bak.$(date +%F-%H%M%S)"
  fi

  if [ -f /etc/nsswitch.conf ]; then
    cp /etc/nsswitch.conf "/etc/nsswitch.conf.bak.$(date +%F-%H%M%S)"
  fi

  if [ -f /etc/sssd/sssd.conf ]; then
    if [ "$USE_FQDN_LOGINS" = "no" ]; then
      sed -i -e 's/use_fully_qualified_names = True/use_fully_qualified_names = False/g' /etc/sssd/sssd.conf 2>/dev/null || true
    fi

    if [ -n "$ACCESS_PROVIDER" ]; then
      sed -i -e "s/access_provider = .*/access_provider = $ACCESS_PROVIDER/g" /etc/sssd/sssd.conf 2>/dev/null || true
    fi

    if ! grep -qi '^override_homedir' /etc/sssd/sssd.conf; then
      echo "override_homedir = $OVERRIDE_HOMEDIR" >> /etc/sssd/sssd.conf
    fi

    if ! grep -qi '^\[nss\]' /etc/sssd/sssd.conf; then
      {
        echo "[nss]"
        echo "filter_groups = root"
        echo "filter_users = root"
        echo "reconnection_retries = 3"
        echo "entry_cache_timeout = 600"
        echo "# cache_credentials = TRUE"
        echo "entry_cache_nowait_percentage = 75"
      } >> /etc/sssd/sssd.conf
    fi

    systemctl restart sssd || true
  fi
fi

if [ "$ENABLE_SHARE_MOUNT" = "yes" ]; then
  echo "Configuration du montage automatique du partage //$SHARE_SERVER/$SHARE_NAME ..."
  mkdir -p "$MOUNT_POINT"

  if [ ! -f "$SHARE_CREDENTIALS_FILE" ]; then
    echo "Création du fichier de credentials pour le partage (mot de passe demandé pour $SHARE_DOMAIN\\$SHARE_USER) ..."
    read -s -p "Mot de passe pour $SHARE_DOMAIN\\$SHARE_USER: " SHARE_PASSWORD
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

  echo "Montage du partage..."
  mount -a
fi

echo "Installation et configuration terminées. Veuillez tester la connexion avec un utilisateur du domaine."
