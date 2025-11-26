# Active Directory join scripts

This project contains shell scripts to automate joining a Linux machine to an Active Directory domain with advanced network shares and sudo permissions configuration.

## Prerequisites

- Debian/Ubuntu based Linux distribution
- Root access (or `sudo`)
- An Active Directory account allowed to join machines to the domain
- Network access to the domain controller and optionally to the file server

## Contents

- `Linux-AD.sh`: main interactive script for AD domain join with shares and sudo groups configuration
- `Linux-AD.conf`: external configuration file for non-interactive usage
- `ressources/`: directory containing modular scripts
  - `backup.sh`: backup/restore functions for configuration files
  - `share.sh`: automatic network shares configuration with PAM mount and Kerberos
  - `sudo_groupes.sh`: Active Directory sudo groups configuration
- `shares.conf`: network shares configuration file (advanced format)

## Linux-AD.sh

### 1. Interactive usage

1. Make the script executable:
   - `chmod +x Linux-AD.sh`

2. Run the script as root:
   - `sudo ./Linux-AD.sh`

The script will interactively ask for:
- The AD domain name (example `mydomain.local`)
- The AD account with permission to join the machine to the domain
- The domain controller IP address (DNS server)
- Whether to configure automatic network shares mounting
- Whether to configure Active Directory sudo groups

### 2. Usage with configuration file

1. Create/edit the `Linux-AD.conf` file with your parameters:

Core variables:

- `DOMAIN`: AD domain name (example `mydomain.local`)
- `AD_USER`: AD account with permission to join the machine to the domain
- `DNS_SERVER`: IP address of the domain controller (AD DNS server)

Network shares options:

- `ENABLE_SHARE`: `Y` to enable, `N` to disable (default)
- `SHARE_SERVER`: hostname or IP of the file server (example `filesrv01`)
- `SHARE_NAME`: share name (example `Services`)
- `SHARE_DOMAIN`: domain used to authenticate to the share (default `DOMAIN`)
- `SHARE_USER`: AD user used to access the share (default `AD_USER`)

Sudo options:

- `ENABLE_SUDO`: `Y` to enable, `N` to disable (default)
- `SUDO_GROUP`: name of the AD group with sudo rights (example `admin`)

2. Run the script with the configuration file:
   - `sudo ./Linux-AD.sh Linux-AD.conf`

The script will:

- Update the system and install required packages (realmd, sssd, samba, `cifs-utils`, `libpam-mount`, etc.).
- Try to automatically fix `apt` repositories if `apt update` fails (add Ubuntu 24.04 LTS repositories then retry).
- Configure DNS to point to the domain controller.
- Discover and join the domain using `realm` (handles case where machine is already joined).
- Enable automatic creation of `home` directories for AD users.
- Restart `sssd` and allow domain users (`realm permit --all`).
- Configure AD sudo groups if enabled.
- Configure network shares with PAM mount and Kerberos if enabled.

### 3. Network shares configuration

If `ENABLE_SHARE="Y"`:

The script uses `ressources/share.sh` to configure PAM mount with Kerberos authentication:
- Installs `libpam-mount`
- Configures `/etc/security/pam_mount.conf.xml` for automatic shares mounting
- Adds PAM mount to PAM services (`common-auth`, `common-session`, `common-password`)
- Shares are mounted in `/mnt/%(USER)/[share_name]` with Kerberos authentication
- No credentials file needed (uses Kerberos tickets)

### 4. Sudo groups configuration

If `ENABLE_SUDO="Y"`:

The script uses `ressources/sudo_groupes.sh` to:
- Create entries in `/etc/sudoers.d/ad_groups`
- Grant full sudo rights without password to specified AD groups
- Format: `%group@domain ALL=(ALL:ALL) NOPASSWD: ALL`

### 5. External configuration file: Linux-AD.conf

`Linux-AD.sh` can load an external configuration file passed as argument. This file can override default variables without editing the script.

Complete example:

```bash
# Main configuration
DOMAIN="mydomain.local"
AD_USER="Administrator"
DNS_SERVER="192.168.0.1"

# Shares configuration
ENABLE_SHARE="Y"
SHARE_SERVER="filesrv01"
SHARE_NAME="Services"
SHARE_DOMAIN="mydomain.local"
SHARE_USER="Administrator"

# Sudo configuration
ENABLE_SUDO="Y"
SUDO_GROUP="admin"
```

Usage with configuration:
```bash
sudo ./Linux-AD.sh Linux-AD.conf
```

## Modular scripts in ressources/

### backup.sh

Backup and restore functions for critical configuration files. Used by other scripts to secure modifications.

### share.sh

Standalone script to configure network shares with PAM mount and Kerberos:

```bash
# Single share usage
bash ressources/share.sh filesrv01 Services

# Multiple shares usage
bash ressources/share.sh filesrv01 "Services Common Projects"
```

Features:
- Kerberos authentication (no credentials files)
- Automatic mounting on user login
- Automatic unmounting on logout
- Mount points: `/mnt/%(USER)/[share_name]`

### sudo_groupes.sh

Standalone script to configure Active Directory sudo groups:

```bash
# Single group
bash ressources/sudo_groupes.sh mydomain.local admin

# Multiple groups
bash ressources/sudo_groupes.sh mydomain.local admin "IT Support" "Domain Admins"
```

Creates entries in `/etc/sudoers.d/ad_groups` with full rights without password.

## shares.conf file

Advanced configuration file for shares (not directly used by Linux-AD.sh but useful for reference):

Format: `share_name:mount_point:server`

Examples:
```
homes:/mnt/%(USER):filesrv01
shared:/mnt/shared:filesrv01
projects:/mnt/projects/%(USER):filesrv01
admin:/mnt/admin:filesrv01
```

Supported variables:
- `%(USER)`: replaced by username
- Optional server: uses default server if not specified

## Kerberos authentication for shares

Unlike the old version that used CIFS credentials files, the new version uses integrated Kerberos authentication:

- **Advantages**: No passwords stored in clear text, single sign-on (SSO), enhanced security
- **How it works**: Kerberos tickets obtained during user login are reused to mount shares
- **Configuration**: Automatically managed by PAM mount with `sec=krb5` option
- **Mount points**: `/mnt/%(USER)/[share_name]` (automatically created)

## Security

- **No credentials files**: Kerberos authentication eliminates the need to store passwords
- **Restrictive permissions**: Modified configuration files have appropriate permissions
- **Automatic backups**: The `backup.sh` module protects critical files before modification
- **Share isolation**: Each user has their own mount points

## Troubleshooting

### Domain join verification

```bash
# Check domain status
realm list

# Test AD user
id user@domain.local

# Check SSSD
systemctl status sssd
tail -f /var/log/sssd/sssd.log
```

### Shares verification

```bash
# Check PAM mount configuration
cat /etc/security/pam_mount.conf.xml

# Test manual mounting (requires Kerberos ticket)
kinit user@domain.local
mount -t cifs -o sec=krb5,cruid=user //filesrv01/Services /mnt/user/Services

# Check PAM logs
tail -f /var/log/auth.log
```

### Common issues

1. **Shares not mounting**: Check that user has valid Kerberos ticket (`klist`)
2. **Permission denied**: Verify AD user has rights on the network share
3. **SSSD not starting**: Check configuration in `/etc/sssd/sssd.conf`

## Post-deployment testing

1. **User login**:
   - Test in TTY: `su - user@domain.local`
   - Test via SSH: `ssh user@domain.local@machine`
   - Verify home directory creation

2. **Sudo permissions** (if configured):
   - `sudo whoami` should return "root" without password

3. **Network shares** (if configured):
   - Login with AD user
   - Verify `/mnt/user/[share]` exists and is accessible
   - `df -h` should show mounted shares

4. **Single sign-on**:
   - After login, `klist` should show Kerberos ticket
   - Share access should not prompt for password
