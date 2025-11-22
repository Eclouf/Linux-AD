# Active Directory join scripts

This project contains shell scripts to automate joining a Linux machine to an Active Directory domain and optionally configure an automatic CIFS share mount.

## Prerequisites

- Debian/Ubuntu based Linux distribution
- Root access (or `sudo`)
- An Active Directory account allowed to join machines to the domain
- Network access to the domain controller and optionally to the file server

## Contents

- `join_ad.sh`: main non interactive script for AD domain join, optional network share mounting, optional domain autodetection and optional SSSD tuning.
- `join_ad_interactive.sh`: interactive version that asks for required information step by step.
- `join_ad.conf`: optional external configuration file used by `join_ad.sh`.

## join_ad.sh

### 1. Basic usage

1. Make the script executable:
   - `chmod +x join_ad.sh`

2. Either edit variables at the top of the script **or** use `join_ad.conf` (recommended).

Core variables used by the script:

- `DOMAIN`: AD domain name (for example `mydomain.local`)
- `AD_USER`: AD account with permission to join the machine to the domain
- `DNS_SERVER`: IP address of the domain controller (AD DNS server)

3. (Optional) Configure automatic mounting of a CIFS share:

- `ENABLE_SHARE_MOUNT`:
  - `no`: no share is mounted
  - `yes`: enable automatic configuration of a network share
- `SHARE_SERVER`: hostname or IP of the file server (for example `filesrv01`)
- `SHARE_NAME`: share name (for example `Services`)
- `MOUNT_POINT`: local mount point (for example `/mnt/services`)
- `SHARE_DOMAIN`: domain used to authenticate to the share (default `DOMAIN`)
- `SHARE_USER`: AD user used to access the share (default `AD_USER`)
- `SHARE_CREDENTIALS_FILE`: path to the credentials file (default `/etc/samba/creds_share`)

4. Run the script as root:

- `sudo ./join_ad.sh`

The script will:

- Update the system and install required packages (realmd, sssd, samba, etc.).
- Configure DNS to point to the domain controller.
- Optionally autodetect the domain using `realm discover` (see below).
- Discover and join the domain using `realm`.
- Enable automatic creation of `home` directories for AD users.
- Restart `sssd` and allow domain users (`realm permit --all`).
- Optionally tune SSSD configuration (see below).

If `ENABLE_SHARE_MOUNT="yes"`:

- Create a local mount point.
- Create a protected credentials file (if missing) to access the CIFS share.
- Add an entry in `/etc/fstab` to mount the share automatically.
- Run `mount -a` to mount the share immediately.

### 2. External configuration file: join_ad.conf
n+
`join_ad.sh` loads the optional file `join_ad.conf` from the same directory if it exists. This file can override default variables without editing the script.

Example:

```bash
DOMAIN="mydomain.local"
AD_USER="Administrator"
DNS_SERVER="192.168.0.10"

ENABLE_REALM_AUTODETECT="yes"
ENABLE_SSSD_TUNING="yes"
USE_FQDN_LOGINS="no"
OVERRIDE_HOMEDIR="/home/%u"
ACCESS_PROVIDER="simple"
LOG_ENABLED="yes"
LOG_FILE="/var/log/join_ad.log"
```

When `LOG_ENABLED="yes"`, both `join_ad.sh` and `join_ad_interactive.sh` will write all output to `LOG_FILE` while still printing it on screen.

### 3. Domain autodetection

The variable `ENABLE_REALM_AUTODETECT` controls whether the script tries to detect the domain automatically using `realm discover`:

- `ENABLE_REALM_AUTODETECT="no"` (default): the `DOMAIN` value is used as is.
- `ENABLE_REALM_AUTODETECT="yes"`: the script runs `realm discover` and, if a realm is found, replaces `DOMAIN` with the detected value.

### 4. Optional SSSD tuning

If `ENABLE_SSSD_TUNING="yes"`, `join_ad.sh` applies additional SSSD configuration inspired by the ADconnection.sh script. Before changing anything it creates backup copies of:

- `/etc/sssd/sssd.conf`
- `/etc/nsswitch.conf`

Main options:

- `USE_FQDN_LOGINS`:
  - `no`: use short usernames (`user`) instead of `user@domain` where possible.
- `OVERRIDE_HOMEDIR`:
  - pattern used for home directories (for example `/home/%u`).
- `ACCESS_PROVIDER`:
  - provider value for SSSD access (for example `ad` or `simple`).

The script then restarts `sssd`.

## join_ad_interactive.sh

`join_ad_interactive.sh` provides an interactive way to join the machine to the domain.

It will:

- Ask for the domain name, AD user, domain controller IP.
- Ask whether to configure an automatic CIFS share mount, and if yes, ask for all required share parameters.
- Install required packages, configure DNS, discover and join the domain.
- Enable automatic home directory creation and configure the share mount.

Usage:

```bash
chmod +x join_ad_interactive.sh
sudo ./join_ad_interactive.sh
```

## Security

- The credentials file for CIFS shares is created with restrictive permissions (`chmod 600`).
- Configuration files are backed up before SSSD tuning.
- Do not share the credentials file and review your backup and export policies for the machine.

## Tests

After running the scripts:

- Test login with a domain user (TTY, SSH, graphical interface).
- If the share option is enabled, verify the mount:
  - `mount | grep cifs` or `df -h`
  - Access the `MOUNT_POINT` directory.
