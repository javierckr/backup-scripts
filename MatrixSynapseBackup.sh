#!/bin/bash

#
# Bash script for creating backups of Matrix Synapse.
#
# Version 1.0.3
#
# Usage:
# 	- With backup directory specified in the script:  ./MatrixSynapseBackup.sh
# 	- With backup directory specified by parameter: ./MatrixSynapseBackup.sh <backupDirectory> (e.g. ./MatrixSynapseBackup.sh /media/hdd/matrix_backup)
#
# Requirements:
#	- pigz (https://zlib.net/pigz/) for using backup compression. If not available, you can use another compression algorithm (e.g. gzip)
#
# IMPORTANT
# You have to customize this script (directories, DB, etc.) for your actual environment.
# All entries which need to be customized are tagged with "TODO".
#
PASSPHRASE="yourpassphrase"

# Make sure the script exits when any command fails
set -Eeuo pipefail

# Variables
backupMainDir=${1:-} 

if [ -z "$backupMainDir" ]; then
	# TODO: The directory where you store the backups (when not specified by args)
	backupMainDir='/media/hdd/matrix_backup'
else
	backupMainDir=$(echo $backupMainDir | sed 's:/*$::')
fi

currentDate=$(date +"%Y%m%d_%H%M%S")

# The actual directory of the current backup - this is a subdirectory of the main directory above with a timestamp
backupDir="${backupMainDir}/${currentDate}"

# TODO: Use compression for Matrix Synapse installation/lib dir
# When this is the only script for backups, it's recommend to enable compression.
# If the output of this script is used in another (compressing) backup (e.g. borg backup), 
# you should probably disable compression here and only enable compression of your main backup script.
useCompression=true

# TOOD: The bare tar command for using compression.
# Use 'tar -cpzf' if you want to use gzip compression.
compressionCommand="tar -I pigz -cpf"

# TODO: The directory of your Matrix Synapse installation (this is a directory under your web root)
matrixInstallDir='/etc/matrix-synapse'

# TODO: The lib directory of Matrix Synapse
matrixLibDir='/var/lib/matrix-synapse'

# TODO: The name of the database system (one of: postgresql, sqlite)
databaseSystem='postgresql'

#########################
# Specific for PostgreSQL
# You do not have to set these values if using SQLite.
#

# TODO: Your Matrix Synapse database name
matrixDatabase='synapse_db'

# TODO: Your Matrix Syapse database user
dbUser='synapse_db_user'

# TODO: The password of the Matrix Synapse database user
dbPassword='mYpAsSw0rd'

# Specific for PostgreSQL
#########################

#####################
# Specific for SQLite
# You do not have to set these values if using PostgreSQL.
#
# TODO: Database file
databaseFileSqlite='/var/lib/matrix-synapse/homeserver.db'

# TODO: Backup file database
fileNameBackupDbFile='homeserver.db'

# Specific for SQLite
#####################

# TODO: The maximum number of backups to keep (when set to 0, all backups are kept)
maxNrOfBackups=0

# File names for backup files
# If you prefer other file names, you'll also have to change the MatrixSynapseRestore.sh script.
fileNameBackupInstallDir='matrix-installdir.tar'
fileNameBackupLibDir='matrix-libdir.tar'

if [ "$useCompression" = true ] ; then
	fileNameBackupInstallDir='matrix-installdir.tar.gz'
	fileNameBackupLibDir='matrix-libdir.tar.gz'
fi

fileNameBackupDb='matrix-db.sql'

# Function for error messages
errorecho() { cat <<< "$@" 1>&2; }

# Capture CTRL+C
trap CtrlC INT

function CtrlC() {
	echo
	echo "Starting Matrix Synapse..."
	systemctl start matrix-synapse
	echo "Done"
	echo

	exit 1
}

#
# Print information
#
echo "Backup directory: ${backupMainDir}"

#
# Check for root
#
if [ "$(id -u)" != "0" ]
then
	errorecho "ERROR: This script has to be run as root!"
	exit 1
fi

#
# Check if backup dir already exists
#
if [ ! -d "${backupDir}" ]
then
	mkdir -p "${backupDir}"
else
	errorecho "ERROR: The backup directory ${backupDir} already exists!"
	exit 1
fi

#
# Stop Matrix Synapse
#
echo "$(date +"%H:%M:%S"): Stopping Matrix Synapse..."
systemctl stop matrix-synapse
echo "Done"
echo

#
# Backup install directory
#
echo "$(date +"%H:%M:%S"): Creating backup of Matrix Synapse install directory..."

if [ "$useCompression" = true ] ; then
	`$compressionCommand "${backupDir}/${fileNameBackupInstallDir}" -C "${matrixInstallDir}" .`
else
	tar -cpf "${backupDir}/${fileNameBackupInstallDir}" -C "${matrixInstallDir}" .
fi

echo "Done"
echo

#
# Backup lib directory
#
echo "$(date +"%H:%M:%S"): Creating backup of Matrix Synapse lib directory..."

if [ "$useCompression" = true ] ; then
	`$compressionCommand "${backupDir}/${fileNameBackupLibDir}"  -C "${matrixLibDir}" .`
else
	tar -cpf "${backupDir}/${fileNameBackupLibDir}"  -C "${matrixLibDir}" .
fi

echo "Done"
echo

#
# Backup DB
#
if [ "${databaseSystem,,}" = "postgresql" ] || [ "${databaseSystem,,}" = "pgsql" ]; then
	echo "$(date +"%H:%M:%S"): Backup Matrix Synapse database (PostgreSQL)..."

	if ! [ -x "$(command -v pg_dump)" ]; then
		errorecho "ERROR: PostgreSQL not installed (command pg_dump not found)."
		errorecho "ERROR: No backup of database possible!"
	else
		PGPASSWORD="${dbPassword}" pg_dump "${matrixDatabase}" -h localhost -U "${dbUser}" -f "${backupDir}/${fileNameBackupDb}"
	fi
	
	echo "Done"
	echo
else
	# Omit backup if DB file is part of the lib dir
	if [[ $databaseFileSqlite != $matrixLibDir* ]]
	then
    	echo "$(date +"%H:%M:%S"): Backup Matrix Synapse database (SQLite)..."

    	cp "${databaseFileSqlite}" "${backupDir}/${fileNameBackupDbFile}"

    	echo "Done"
		echo
	fi
fi

#
# Start Matrix Synapse
#
echo "$(date +"%H:%M:%S"): Starting Matrix Synapse..."
systemctl start matrix-synapse
echo "Done"
echo

#
# Delete old backups
#
if [ ${maxNrOfBackups} != 0 ]
then
	nrOfBackups=$(ls -l ${backupMainDir} | grep -c ^d)

	if [ ${nrOfBackups} -gt ${maxNrOfBackups} ]
	then
		echo "$(date +"%H:%M:%S"): Removing old backups..."
		ls -t ${backupMainDir} | tail -$(( nrOfBackups - maxNrOfBackups )) | while read -r dirToRemove; do
			echo "${dirToRemove}"
			rm -r "${backupMainDir}/${dirToRemove:?}"
			echo "Done"
			echo
		done
	fi
fi

echo
echo "DONE!"
echo "$(date +"%H:%M:%S"): Backup created: ${backupDir}"
