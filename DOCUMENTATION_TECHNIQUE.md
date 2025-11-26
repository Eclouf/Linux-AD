# Documentation Technique des Commandes

Ce document détaille chaque commande utilisée dans les scripts Linux-AD avec leurs options et alternatives.

## Table des matières
- [Commandes système](#commandes-système)
- [Commandes de gestion des paquets](#commandes-de-gestion-des-paquets)
- [Commandes Active Directory](#commandes-active-directory)
- [Commandes de montage CIFS](#commandes-de-montage-cifs)
- [Commandes PAM](#commandes-pam)
- [Commandes SSSD](#commandes-sssd)
- [Commandes réseau](#commandes-réseau)
- [Commandes de fichiers](#commandes-de-fichiers)

---

## Commandes système

### `id`
**Utilisation** : `id [utilisateur]`
**Script** : Vérification des utilisateurs AD
**Options** :
- Aucune option requise
- Affiche UID, GID et groupes de l'utilisateur

**Alternatives** :
- `getent passwd [utilisateur]` : Informations sur l'utilisateur
- `wbinfo -u` : Liste des utilisateurs AD (Winbind)

### `systemctl`
**Utilisation** : `systemctl [action] [service]`
**Script** : Gestion des services système
**Options utilisées** :
- `restart [service]` : Redémarrer un service
- `status [service]` : Vérifier l'état d'un service
- `enable [service]` : Activer au démarrage
- `start [service]` : Démarrer un service

**Services gérés** :
- `sssd` : System Security Services Daemon
- `adsysd.service` : Active Directory sys service (commenté)

**Options supplémentaires** :
- `stop [service]` : Arrêter un service
- `disable [service]` : Désactiver au démarrage
- `is-active [service]` : Vérifier si actif
- `is-enabled [service]` : Vérifier si activé

---

## Commandes de gestion des paquets

### `apt update`
**Utilisation** : `apt update [options]`
**Script** : Mise à jour des listes de paquets
**Options utilisées** :
- `-y` : Confirmation automatique

**Options supplémentaires** :
- `--quiet` : Mode silencieux
- `--allow-releaseinfo-change` : Autoriser changement de version

### `apt upgrade`
**Utilisation** : `apt upgrade [options]`
**Script** : Mise à niveau des paquets installés
**Options utilisées** :
- `-y` : Confirmation automatique

**Options supplémentaires** :
- `--safe-upgrade` : Mise à niveau sécurisée
- `--with-new-pkgs` : Autoriser nouveaux paquets

### `apt install`
**Utilisation** : `apt install [paquets] [options]`
**Script** : Installation des dépendances
**Paquets installés** :
- `realmd` : Gestion des domaines
- `sssd` : Service d'authentification
- `sssd-tools` : Outils SSSD
- `libnss-sss` : Bibliothèques NSS
- `libpam-sss` : Bibliothèques PAM
- `adcli` : Outils AD CLI
- `samba-common-bin` : Outils Samba
- `oddjob` : Service de tâches
- `oddjob-mkhomedir` : Création de home directories
- `packagekit` : Gestion de paquets
- `cifs-utils` : Utils CIFS/SMB
- `libpam-mount` : Montage PAM

**Options utilisées** :
- `-y` : Confirmation automatique

**Options supplémentaires** :
- `--no-install-recommends` : Ne pas installer les recommandés
- `--fix-broken` : Réparer les dépendances cassées

---

## Commandes Active Directory

### `realm`
**Utilisation** : `realm [commande] [options]`
**Script** : Gestion du domaine Active Directory

#### `realm discover`
**Utilisation** : `realm discover [domaine]`
**Script** : Découverte du domaine
**Options** :
- Domaine cible (ex: `mondomaine.local`)

**Options supplémentaires** :
- `--verbose` : Mode verbeux
- `--all` : Afficher toutes les informations

#### `realm join`
**Utilisation** : `realm join [options] [domaine]`
**Script** : Jonction au domaine
**Options utilisées** :
- `-U [utilisateur]` : Utilisateur pour la jonction

**Options supplémentaires** :
- `--computer-ou=[OU]` : Unité organisationnelle
- `--no-password` : Pas de mot de passe (kerberos)
- `--automatic-id-mapping=no` : Désactiver mapping automatique

#### `realm permit`
**Utilisation** : `realm permit [options]`
**Script** : Autorisation des utilisateurs
**Options utilisées** :
- `--all` : Autoriser tous les utilisateurs du domaine

**Options supplémentaires** :
- `[utilisateur]` : Utilisateur spécifique
- `[groupe]` : Groupe spécifique

#### `realm list`
**Utilisation** : `realm list`
**Script** : Afficher les domaines configurés
**Options** : Aucune

---

## Commandes de montage CIFS

### `mount`
**Utilisation** : `mount [options] [périphérique] [point]`
**Script** : Montage des partages réseau

#### Montage CIFS avec Kerberos
**Commande complète** :
```bash
mount -t cifs -o sec=krb5,cruid=%(USER),uid=%(USER),gid=%(USER),file_mode=0644,dir_mode=0755 //serveur/partage /mnt/utilisateur/partage
```

**Options CIFS** :
- `-t cifs` : Type de système de fichiers CIFS
- `sec=krb5` : Sécurité Kerberos
- `cruid=%(USER)` : UID utilisateur pour les credentials
- `uid=%(USER)` : UID propriétaire des fichiers
- `gid=%(USER)` : GID propriétaire des fichiers
- `file_mode=0644` : Permissions fichiers
- `dir_mode=0755` : Permissions répertoires

**Options supplémentaires** :
- `username=[user]` : Nom d'utilisateur (authentification basic)
- `password=[pass]` : Mot de passe
- `domain=[domain]` : Domaine AD
- `vers=3.0` : Version SMB/CIFS
- `iocharset=utf8` : Encodage des caractères

### `mount -a`
**Utilisation** : `mount -a [options]`
**Script** : Monter tous les systèmes de fichiers
**Options** : Aucune

**Options supplémentaires** :
- `-t [type]` : Type spécifique
- `-O [options]` : Filtrer par options de montage

---

## Commandes PAM

### `pam-auth-update`
**Utilisation** : `pam-auth-update [options]`
**Script** : Mise à jour de la configuration PAM
**Options utilisées** :
- `--enable [module]` : Activer un module PAM

**Modules activés** :
- `mkhomedir` : Création automatique des home directories
- `pam_mount` : Montage automatique des partages

**Options supplémentaires** :
- `--disable [module]` : Désactiver un module
- `--package` : Mode package
- `--force` : Forcer la mise à jour

### Configuration PAM directe
**Scripts** : Ajout de modules PAM dans les fichiers de configuration

**Fichiers modifiés** :
- `/etc/pam.d/common-auth` : Authentification
- `/etc/pam.d/common-session` : Session
- `/etc/pam.d/common-password` : Mot de passe

**Entrées ajoutées** :
```
auth optional pam_mount.so
session optional pam_mount.so
password optional pam_mount.so
```

**Options PAM mount** :
- `optional` : Non critique si échec
- `required` : Obligatoire
- `sufficient` : Suffisant si succès

---

## Commandes SSSD

### `kinit`
**Utilisation** : `kinit [principal]`
**Script** : Obtention d'un ticket Kerberos
**Options** :
- Principal Kerberos (ex: `utilisateur@domaine.local`)

**Options supplémentaires** :
- `-k` : Utiliser keytab
- `-t [keytab]` : Fichier keytab
- `-R [lifetime]` : Durée de vie du ticket
- `-f` : Forwardable ticket

### `klist`
**Utilisation** : `klist [options]`
**Script** : Vérification des tickets Kerberos
**Options** : Aucune

**Options supplémentaires** :
- `-v` : Mode verbeux
- `-s` : Court statut
- `-k` : Keytab tickets

---

## Commandes réseau

### Configuration DNS
**Script** : Modification de `/etc/resolv.conf`

**Commande** :
```bash
echo -e "nameserver $DNS_SERVER\nsearch $DOMAIN" > /etc/resolv.conf
```

**Options** :
- `nameserver [IP]` : Serveur DNS primaire
- `search [domaine]` : Domaine de recherche

**Format resolv.conf** :
```
nameserver 192.168.0.1
search mondomaine.local
```

---

## Commandes de fichiers

### `chmod`
**Utilisation** : `chmod [permissions] [fichier]`
**Script** : Modification des permissions de fichiers

**Options utilisées** :
- `600` : Lecture/écriture propriétaire uniquement
- `755` : Lecture/écriture propriétaire, lecture/execution groupe et autres

**Options supplémentaires** :
- `-R` : Récursif
- `a+r` : Ajouter lecture pour tous
- `u+x` : Ajouter exécution propriétaire

### `chown`
**Utilisation** : `chown [propriétaire][:groupe] [fichier]`
**Script** : Changement de propriétaire

**Options utilisées** :
- `root:root` : Propriétaire root

**Options supplémentaires** :
- `-R` : Récursif
- `--from=[ancien]` : Changer depuis ancien propriétaire

### `mkdir`
**Utilisation** : `mkdir [options] [répertoire]`
**Script** : Création de répertoires

**Options utilisées** :
- `-p` : Créer les répertoires parents si nécessaire

**Options supplémentaires** :
- `-m [permissions]` : Permissions à la création
- `-v` : Mode verbeux

### `cp`
**Utilisation** : `cp [options] [source] [destination]`
**Script** : Copie de fichiers de sauvegarde

**Options utilisées** :
- Sauvegarde avec timestamp : `cp fichier fichier.bak.$(date +%F-%H%M%S)`

**Options supplémentaires** :
- `-r` : Récursif
- `-a` : Archive (préserve attributs)
- `-v` : Mode verbeux
- `--backup=numbered` : Sauvegarde numérotée

---

## Commandes de log et monitoring

### `tail`
**Utilisation** : `tail [options] [fichier]`
**Script** : Surveillance des logs
**Options utilisées** :
- `-f` : Suivre en temps réel

**Fichiers de log** :
- `/var/log/sssd/sssd.log` : Logs SSSD
- `/var/log/auth.log` : Logs d'authentification

**Options supplémentaires** :
- `-n [lignes]` : Nombre de lignes
- `--pid=[PID]` : Suivre un processus spécifique

### `journalctl`
**Utilisation** : `journalctl [options]`
**Script** : Logs système (alternative à tail)

**Options utiles** :
- `-u [service]` : Logs d'un service spécifique
- `-f` : Suivre en temps réel
- `--since=[date]` : Depuis une date
- `-n [lignes]` : Nombre de lignes

---

## Commandes de test et diagnostic

### `ping`
**Utilisation** : `ping [options] [hôte]`
**Script** : Test de connectivité réseau
**Options** :
- `-c [nombre]` : Nombre de paquets
- `-i [intervalle]` : Intervalle entre paquets

### `nslookup` / `dig`
**Utilisation** : `nslookup [nom] [serveur]`
**Script** : Test de résolution DNS
**Options** :
- Nom à résoudre
- Serveur DNS optionnel

**Alternative dig** :
```bash
dig @serveur_dns nom_a_resoudre
```

---

## Variables et substitutions utilisées

### Variables système
- `$DOMAIN` : Nom du domaine AD
- `$AD_USER` : Utilisateur AD
- `$DNS_SERVER` : Serveur DNS
- `$SHARE_SERVER` : Serveur de partages
- `$SHARE_NAME` : Nom du partage

### Substitutions PAM mount
- `%(USER)` : Nom d'utilisateur connecté
- `%(USERUID)` : UID numérique de l'utilisateur
- `%(USERGID)` : GID numérique de l'utilisateur

### Substitutions shell
- `$(date +%F-%H%M%S)` : Timestamp formaté
- `$(dirname "$LOG_FILE")` : Répertoire du fichier de log
- `${BASH_SOURCE[0]}` : Chemin du script courant

---

## Options de sécurité et bonnes pratiques

### Permissions recommandées
- Fichiers de configuration : `600` ou `640`
- Scripts exécutables : `755`
- Répertoires de montage : `755`
- Fichiers de credentials : `600`

### Sauvegardes automatiques
- Timestamp sur les fichiers de sauvegarde
- Extension `.bak.` avant modification
- Restauration automatique en cas d'erreur

### Validation des entrées
- Vérification des permissions root
- Validation des paramètres requis
- Gestion des erreurs avec trap ERR
