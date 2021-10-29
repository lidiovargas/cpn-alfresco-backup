#!/bin/bash
# Run this script to backup database of sienge with restic, to local file
# Run as admin (sudo)
# REQUIRED: The repository need to be crated, with command : $ restic init --repo /archive/diff/sienge/db
# REQUIRED: rclone installed, and configured to windows-server remote
# REQUIRED: export RESTIC_PASSWORD = yourpassword (or permanente environment variables)

LOG_FILE="/var/lib/docker/volumes/log/_data/backup/sienge.bkp.diff.local.log"
RCLONE_REMOTE_NAME="windows-server"
CURRENT="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)" 
RCONFIG="$CURRENT/rclone.conf"

nowstamp() {  

	echo $(date "+%Y/%m/%d %H:%M:%S")  
}
printf "\n\n" >> $LOG_FILE

echo $(nowstamp) Creating/Updating cron file >> $LOG_FILE
CRON_NAME=/etc/cron.d/sienge-bkp-diff-local
# Run at 2:20AM every day
echo "20 02 * * * root $CURRENT/sienge.bkp.diff.local.sh 2>&1" > $CRON_NAME
chmod 0600 $CRON_NAME

## Mounting remote unit with rclone for windows.cpn.com.br
echo $(nowstamp) Mounting unit of windows.cpn.com.br with rclone >> $LOG_FILE
MOUNT_FROM="${RCLONE_REMOTE_NAME}:/"
MOUNT_TO="${CURRENT}/windows-server"
mkdir -p $MOUNT_TO >> $LOG_FILE
rclone mount $MOUNT_FROM ${MOUNT_TO}/ --daemon --config=$RCONFIG --log-level=INFO --log-file=$LOG_FILE

sleep 2s #To prevent errors with script execution before mountig is done

#Stopping Database
echo $(nowstamp) Stopping Database... >> $LOG_FILE
ssh -t windows.cpn.com.br 'net stop "Firebird Server - SiengeWEB"' >> $LOG_FILE
sleep 10s

# Restic backup commands...
RESTIC_REPO_LOCAL="/archive/diff/sienge/db"
FROM_BACKUP=${MOUNT_TO}/cygdrive/d/SiengeWEB/Data/SIENGE.FDB
restic --repo $RESTIC_REPO_LOCAL --verbose backup $FROM_BACKUP >> $LOG_FILE

#Startin Database
echo $(nowstamp) Starting Database... >> $LOG_FILE
ssh -t windows.cpn.com.br 'net start "Firebird Server - SiengeWEB"' >> $LOG_FILE
sleep 1s

# Unmount
echo $(nowstamp) Unmounting unit ${MOUNT_TO} >> $LOG_FILE
fusermount -u $MOUNT_TO >> $LOG_FILE
rm -r $MOUNT_TO >> $LOG_FILE

echo Consulte o arquivo de log gerado em $LOG_FILE
