#!/bin/sh
#
# Backup /etc directory on openwrt router

# Constants
ROOT_UID=0
E_NOTROOT=87
# Check root privileges
if [ "$UID" -ne "$ROOT_UID" ]
then
    echo "Must be root to run this script."
    exit $E_NOTROOT
fi
# Set variables
# Set passphrase, this should be different for each host
PASSPHRASE=yourpassphrase
# Set backup directory
BACKUPDIR=/etc/
# Set backup filename
BACKUPFILE=backupetc$(date +%Y%m%d)$(hostname).tar.gz.gpg
# Set backup destination
# This is the remote server where the backup file will be copied
HOST=hostname
# This is the user on the remote server where the backup file will be copied
USER=ftpuser
# This is the directory on the remote server where the backup file will be copied
BACKUPDEST=/media/netdrive/ftp/backups/$(hostname)/etc/

# Create backup
tar -zcvf $BACKUPDIR |\
    gpg -c --batch --passphrase "$PASSPHRASE" |\
    ssh -i /root/.ssh/id_rsa $USER@$HOST "cat > $BACKUPDEST$BACKUPFILE" &&\
    logger -t backupetc "Backup of /etc directory completed successfully" ||\
    logger -t backupetc "Backup of /etc directory failed" 2>&1 |\
    tee -a /var/log/backupetc.log
