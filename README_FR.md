# Scripts de jonction au domaine Active Directory

Ce projet contient des scripts shell pour automatiser la jonction d'une machine Linux à un domaine Active Directory avec configuration avancée des partages réseau et des permissions sudo.

## Prérequis

- Distribution Linux de type Debian/Ubuntu
- Accès root (ou `sudo`)
- Un compte Active Directory ayant le droit de joindre des machines au domaine
- Accès réseau au contrôleur de domaine et éventuellement au serveur de fichiers

## Contenu

- `Linux-AD.sh` : script principal interactif pour la jonction au domaine AD avec configuration des partages et groupes sudo
- `Linux-AD.conf` : fichier de configuration externe pour une utilisation non interactive
- `ressources/` : répertoire contenant les scripts modulaires
  - `backup.sh` : fonctions de sauvegarde/restauration des fichiers de configuration
  - `share.sh` : configuration automatique des partages réseau avec PAM mount et Kerberos
  - `sudo_groupes.sh` : configuration des groupes sudo Active Directory
- `shares.conf` : fichier de configuration des partages réseau (format avancé)

## Linux-AD.sh

### 1. Utilisation interactive

1. Rendre le script executable :
   - `chmod +x Linux-AD.sh`

2. Lancer le script en root :
   - `sudo ./Linux-AD.sh`

Le script vous demandera interactivement :
- Le nom du domaine AD (exemple `mondomaine.local`)
- Le compte AD ayant les droits pour joindre la machine au domaine
- L'adresse IP du contrôleur de domaine (serveur DNS AD)
- Si vous souhaitez configurer un montage automatique de partages réseau
- Si vous souhaitez configurer des groupes sudo Active Directory

### 2. Utilisation avec fichier de configuration

1. Créer/modifier le fichier `Linux-AD.conf` avec vos paramètres :

Variables principales :

- `DOMAIN` : nom du domaine AD (exemple `mondomaine.local`)
- `AD_USER` : compte AD ayant les droits pour joindre la machine au domaine
- `DNS_SERVER` : adresse IP du contrôleur de domaine (serveur DNS AD)

Options de partage réseau :

- `ENABLE_SHARE` : `Y` pour activer, `N` pour désactiver (défaut)
- `SHARE_SERVER` : nom ou IP du serveur de fichiers (exemple `filesrv01`)
- `SHARE_NAME` : nom du partage (exemple `Services`)
- `SHARE_DOMAIN` : domaine utilisé pour l'authentification au partage (par défaut `DOMAIN`)
- `SHARE_USER` : utilisateur AD utilisé pour accéder au partage (par défaut `AD_USER`)

Options sudo :

- `ENABLE_SUDO` : `Y` pour activer, `N` pour désactiver (défaut)
- `SUDO_GROUP` : nom du groupe AD ayant droits sudo (exemple `admin`)

2. Lancer le script avec le fichier de configuration :
   - `sudo ./Linux-AD.sh Linux-AD.conf`

Le script :

- Met à jour le système et installe les paquets nécessaires (realmd, sssd, samba, `cifs-utils`, `libpam-mount`, etc.).
- Tente une réparation automatique des dépôts `apt` si `apt update` échoue (ajout des dépôts Ubuntu 24.04 LTS puis nouvel essai).
- Configure le DNS pour pointer vers le contrôleur de domaine.
- Découvre et joint le domaine via `realm` (gère le cas où la machine est déjà jointe au domaine).
- Active la création automatique des dossiers `home` pour les utilisateurs AD.
- Redémarre `sssd` et autorise les utilisateurs du domaine (`realm permit --all`).
- Configure les groupes sudo AD si activé.
- Configure les partages réseau avec PAM mount et Kerberos si activé.

### 3. Configuration des partages réseau

Si `ENABLE_SHARE="Y"` :

Le script utilise `ressources/share.sh` pour configurer PAM mount avec authentification Kerberos :
- Installe `libpam-mount`
- Configure `/etc/security/pam_mount.conf.xml` pour monter automatiquement les partages
- Ajoute PAM mount dans les services PAM (`common-auth`, `common-session`, `common-password`)
- Les partages sont montés dans `/mnt/%(USER)/[nom_partage]` avec authentification Kerberos
- Aucun fichier de credentials n'est nécessaire (utilisation de tickets Kerberos)

### 4. Configuration des groupes sudo

Si `ENABLE_SUDO="Y"` :

Le script utilise `ressources/sudo_groupes.sh` pour :
- Créer des entrées dans `/etc/sudoers.d/ad_groups`
- Donner les droits sudo complets sans mot de passe aux groupes AD spécifiés
- Format : `%groupe@domaine ALL=(ALL:ALL) NOPASSWD: ALL`

### 5. Fichier de configuration externe : Linux-AD.conf

`Linux-AD.sh` peut charger un fichier de configuration externe passé en argument. Ce fichier permet de surcharger les valeurs par défaut sans modifier le script.

Exemple complet :

```bash
# Configuration principale
DOMAIN="mondomaine.local"
AD_USER="Administrateur"
DNS_SERVER="192.168.0.1"

# Configuration des partages
ENABLE_SHARE="Y"
SHARE_SERVER="filesrv01"
SHARE_NAME="Services"
SHARE_DOMAIN="mondomaine.local"
SHARE_USER="Administrateur"

# Configuration sudo
ENABLE_SUDO="Y"
SUDO_GROUP="admin"
```

Utilisation avec configuration :
```bash
sudo ./Linux-AD.sh Linux-AD.conf
```

## Scripts modulaires dans ressources/

### backup.sh

Fonctions de sauvegarde et restauration automatique des fichiers de configuration critiques. Utilisé par les autres scripts pour sécuriser les modifications.

### share.sh

Script autonome pour configurer les partages réseau avec PAM mount et Kerberos :

```bash
# Utilisation avec un seul partage
bash ressources/share.sh filesrv01 Services

# Utilisation avec plusieurs partages
bash ressources/share.sh filesrv01 "Services Commun Projects"
```

Caractéristiques :
- Authentification Kerberos (pas de fichiers de credentials)
- Montage automatique à la connexion utilisateur
- Démontage automatique à la déconnexion
- Points de montage : `/mnt/%(USER)/[nom_partage]`

### sudo_groupes.sh

Script autonome pour configurer les groupes sudo Active Directory :

```bash
# Un seul groupe
bash ressources/sudo_groupes.sh mondomaine.local admin

# Plusieurs groupes
bash ressources/sudo_groupes.sh mondomaine.local admin "IT Support" "Domain Admins"
```

Crée des entrées dans `/etc/sudoers.d/ad_groups` avec droits complets sans mot de passe.

## Fichier shares.conf

Fichier de configuration avancée pour les partages (non utilisé directement par Linux-AD.sh mais utile pour référence) :

Format : `nom_partage:point_montage:serveur`

Exemples :
```
homes:/mnt/%(USER):filesrv01
shared:/mnt/shared:filesrv01
projects:/mnt/projects/%(USER):filesrv01
admin:/mnt/admin:filesrv01
```

Variables supportées :
- `%(USER)` : remplacé par le nom d'utilisateur
- Serveur optionnel : utilise le serveur par défaut si non spécifié

## Authentification Kerberos pour les partages

Contrairement à l'ancienne version qui utilisait des fichiers de credentials CIFS, la nouvelle version utilise l'authentification Kerberos intégrée :

- **Avantages** : Pas de mots de passe stockés en clair, authentification unique (SSO), sécurité renforcée
- **Fonctionnement** : Les tickets Kerberos obtenus lors de la connexion utilisateur sont réutilisés pour monter les partages
- **Configuration** : Gérée automatiquement par PAM mount avec l'option `sec=krb5`
- **Points de montage** : `/mnt/%(USER)/[nom_partage]` (créés automatiquement)

## Sécurité

- **Pas de fichiers de credentials** : L'authentification Kerberos élimine le besoin de stocker des mots de passe
- **Droits restrictifs** : Les fichiers de configuration modifiés ont des permissions appropriées
- **Sauvegardes automatiques** : Le module `backup.sh` protège les fichiers critiques avant modification
- **Isolation des partages** : Chaque utilisateur a ses propres points de montage

## Dépannage

### Vérification de la jonction au domaine

```bash
# Vérifier l'état du domaine
realm list

# Tester un utilisateur AD
id utilisateur@domaine.local

# Vérifier SSSD
systemctl status sssd
tail -f /var/log/sssd/sssd.log
```

### Vérification des partages

```bash
# Vérifier la configuration PAM mount
cat /etc/security/pam_mount.conf.xml

# Tester manuellement le montage (nécessite un ticket Kerberos)
kinit utilisateur@domaine.local
mount -t cifs -o sec=krb5,cruid=utilisateur //filesrv01/Services /mnt/utilisateur/Services

# Vérifier les logs PAM
tail -f /var/log/auth.log
```

### Problèmes courants

1. **Partages ne se montent pas** : Vérifier que l'utilisateur a un ticket Kerberos valide (`klist`)
2. **Permissions refusées** : Vérifier que l'utilisateur AD a les droits sur le partage réseau
3. **SSSD ne démarre pas** : Vérifier la configuration dans `/etc/sssd/sssd.conf`

## Tests après déploiement

1. **Connexion utilisateur** :
   - Tester en TTY : `su - utilisateur@domaine.local`
   - Tester via SSH : `ssh utilisateur@domaine.local@machine`
   - Vérifier la création du home directory

2. **Permissions sudo** (si configuré) :
   - `sudo whoami` devrait retourner "root" sans mot de passe

3. **Partages réseau** (si configurés) :
   - Se connecter avec un utilisateur AD
   - Vérifier que `/mnt/utilisateur/[partage]` existe et est accessible
   - `df -h` devrait monter les partages montés

4. **Authentification unique** :
   - Après connexion, `klist` devrait montrer un ticket Kerberos
   - Les accès aux partages ne devraient pas demander de mot de passe
