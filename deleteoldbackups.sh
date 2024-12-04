#!/bin/sh

# Delete backup files older than n days

# Set variables
DAYS=60
BACKUPDIR="/media/netdrive/ftp/backups"

# Delete files older than n days
find $BACKUPDIR -type f -mtime +$DAYS -exec rm {} \ || logger -t deleteoldbackups "Error deleting files" >> /var/log/deletebackup.log 2>&1
