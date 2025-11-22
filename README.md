# Scripts de jonction au domaine Active Directory

Ce projet contient des scripts shell pour automatiser la jonction dune machine Linux a un domaine Active Directory et, optionnellement, configurer un montage automatique dun partage CIFS.

## Prerequis

- Distribution Linux de type Debian/Ubuntu
- Acces root (ou `sudo`)
- Un compte Active Directory ayant le droit de joindre des machines au domaine
- Acces reseau au controleur de domaine et eventuellement au serveur de fichiers

## Contenu

- `join_ad.sh` : script principal non interactif pour la jonction au domaine AD, le montage de partage reseau optionnel, la detection de domaine optionnelle et le tuning SSSD optionnel.
- `join_ad_interactive.sh` : version interactive qui demande les informations necessaires etapes par etapes.
- `join_ad.conf` : fichier de configuration externe optionnel utilise par `join_ad.sh`.

## join_ad.sh

### 1. Utilisation de base

1. Rendre le script executable :
   - `chmod +x join_ad.sh`

2. Soit adapter les variables en haut du script, soit utiliser `join_ad.conf` (recommande).

Variables principales utilisees :

- `DOMAIN` : nom du domaine AD (exemple `mondomaine.local`)
- `AD_USER` : compte AD ayant les droits pour joindre la machine au domaine
- `DNS_SERVER` : adresse IP du controleur de domaine (serveur DNS AD)

3. (Optionnel) Configuration du montage automatique dun partage CIFS :

- `ENABLE_SHARE_MOUNT` :
  - `no` : aucun partage nest monte
  - `yes` : active la configuration automatique dun partage reseau
- `SHARE_SERVER` : nom ou IP du serveur de fichiers (exemple `filesrv01`)
- `SHARE_NAME` : nom du partage (exemple `Services`)
- `MOUNT_POINT` : point de montage local (exemple `/mnt/services`)
- `SHARE_DOMAIN` : domaine utilise pour lautentification au partage (par defaut `DOMAIN`)
- `SHARE_USER` : utilisateur AD utilise pour acceder au partage (par defaut `AD_USER`)
- `SHARE_CREDENTIALS_FILE` : chemin du fichier de credentials (par defaut `/etc/samba/creds_share`)

4. Lancer le script en root :

- `sudo ./join_ad.sh`

Le script :

- Met a jour le systeme et installe les paquets necessaires (realmd, sssd, samba, etc.).
- Configure le DNS pour pointer vers le controleur de domaine.
- Peut detecter automatiquement le domaine via `realm discover` (voir ci dessous).
- Decouvre et joint le domaine via `realm`.
- Active la creation automatique des dossiers `home` pour les utilisateurs AD.
- Redemarre `sssd` et autorise les utilisateurs du domaine (`realm permit --all`).
- Peut appliquer un tuning SSSD optionnel (voir ci dessous).

Si `ENABLE_SHARE_MOUNT="yes"` :

- Cree un point de montage local.
- Cree un fichier de credentials protege (si absent) pour l acces au partage CIFS.
- Ajoute une entree dans `/etc/fstab` pour monter automatiquement le partage.
- Lance `mount -a` pour monter le partage immediatement.

### 2. Fichier de configuration externe : join_ad.conf

`join_ad.sh` charge le fichier optionnel `join_ad.conf` situe dans le meme repertoire sil existe. Ce fichier permet de surcharger les valeurs par defaut sans modifier le script.

Exemple :

```bash
DOMAIN="mondomaine.local"
AD_USER="Administrateur"
DNS_SERVER="192.168.0.10"

ENABLE_REALM_AUTODETECT="yes"
ENABLE_SSSD_TUNING="yes"
USE_FQDN_LOGINS="no"
OVERRIDE_HOMEDIR="/home/%u"
ACCESS_PROVIDER="simple"
LOG_ENABLED="yes"
LOG_FILE="/var/log/join_ad.log"
```

Quand `LOG_ENABLED="yes"`, les scripts `join_ad.sh` et `join_ad_interactive.sh` ecrivent toute leur sortie dans `LOG_FILE` tout en continuant a lafficher a lecran.

### 3. Detection de domaine

La variable `ENABLE_REALM_AUTODETECT` controle la tentative de detection automatique du domaine via `realm discover` :

- `ENABLE_REALM_AUTODETECT="no"` (defaut) : la valeur `DOMAIN` est utilisee telle quelle.
- `ENABLE_REALM_AUTODETECT="yes"` : le script lance `realm discover` et, si un domaine est trouve, remplace `DOMAIN` par la valeur detectee.

### 4. Tuning SSSD optionnel

Si `ENABLE_SSSD_TUNING="yes"`, `join_ad.sh` applique une configuration SSSD supplementaire, inspiree du script ADconnection.sh. Avant toute modification, des sauvegardes sont creees pour :

- `/etc/sssd/sssd.conf`
- `/etc/nsswitch.conf`

Principales options :

- `USE_FQDN_LOGINS` :
  - `no` : utilise des noms courts (`user`) au lieu de `user@domaine` lorsque cest possible.
- `OVERRIDE_HOMEDIR` :
  - modele de chemin pour les dossiers home (par exemple `/home/%u`).
- `ACCESS_PROVIDER` :
  - valeur du provider d acces SSSD (par exemple `ad` ou `simple`).

Le script redemarre ensuite `sssd`.

## join_ad_interactive.sh

`join_ad_interactive.sh` offre une approche interactive pour joindre la machine au domaine.

Il va :

- Demander le nom de domaine, l utilisateur AD et l adresse IP du controleur de domaine.
- Demander si un montage automatique de partage CIFS doit etre configure et, si oui, poser toutes les questions necessaires.
- Installer les paquets, configurer le DNS, decouvrir et joindre le domaine.
- Activer la creation automatique des dossiers home et configurer le montage du partage.

Utilisation :

```bash
chmod +x join_ad_interactive.sh
sudo ./join_ad_interactive.sh
```

## Securite

- Le fichier de credentials pour les partages CIFS est cree avec des droits restrictifs (`chmod 600`).
- Les fichiers de configuration sont sauvegardes avant le tuning SSSD.
- Ne partagez pas le fichier de credentials et verifiez vos strategies de sauvegarde et dexport de la machine.

## Tests

Apres execution des scripts :

- Tester la connexion avec un utilisateur du domaine (TTY, SSH, interface graphique).
- Si l option de partage est activee, verifier le montage :
  - `mount | grep cifs` ou `df -h`
  - Acces au dossier `MOUNT_POINT`.
