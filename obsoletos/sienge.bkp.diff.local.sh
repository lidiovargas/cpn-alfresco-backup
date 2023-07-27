#!/bin/bash

SCRIPT_PREFIX="sienge.bkp.inc.local.sh"

# `scriptname.sh` uses defaut 7168 KB/s (7MB/s) = 56Mbps
# `scriptname.sh --bwlimit=0` uses all available band
# `scriptname.sh --bwlimit=20480` uses 20580 KB/s (20MB/s) = 160Mbps
# `scriptname.sh --stop` stops and restart the services before backup
# `scriptname.sh --update-cron` to update cron.d with the current script

source ./.sienge.aws.env
source ./functions.sh

FROM_RCLONE_REMOTE=windows-server
FROM_SSH_REMOTE=windows.cpn.com.br
FROM_REMOTE_PATH=/cygdrive/d/SiengeWEB
FROM_MOUNT_PATH=/opt/SiengeWEB

# LOG="/var/lib/docker/volumes/log/_data/backup/sienge.bkp.diff.local.log"
LOG=~/logs/sienge.bkp.$(date "+%Y.%m").log
mkdir -p ~/logs && touch $LOG

printf "\n\n" >> $LOG
echo $(nowstamp) Script started: $SCRIPT_PREFIX >> $LOG

if [ $UPDATE_CRON == true ]; then
  echo $(nowstamp) Creating/Updating cron file | tolog
  CRON_NAME=/etc/cron.d/sienge-bkp-inc-local
  # Run at 3AM on Tuesday (2), Thursday (4) and Saturday (6)
  echo "00 03 * * 2,4,6 root $CURRENT/$SCRIPT_PREFIX 2>&1" > $CRON_NAME
  chmod 0600 $CRON_NAME
fi

echo $(nowstamp) Mounting unit $FROM_MOUNT_PATH | tolog
rclone mount $FROM_RCLONE_REMOTE:$FROM_REMOTE_PATH $FROM_MOUNT_PATH --daemon \
	--read-only

sleep 2s #To prevent errors with script execution before mountig is done

if [ $STOP == true ]; then
	echo $(nowstamp) Stopping Database... | tolog
	ssh -t $FROM_SSH_REMOTE 'net stop "Firebird Server - SiengeWEB"' | tolog
	sleep 10s
fi

echo $(nowstamp) Backup ${FROM_MOUNT_PATH}/Data/SIENGE.FDB | tolog
restic backup ${FROM_MOUNT_PATH}/Data/SIENGE.FDB \
	--limit-upload $BWLIMIT --limit-download $BWLIMIT \
	--verbose 2 \
	| tolog

if [ $STOP == true ]; then
	echo $(nowstamp) Stopping Database... | tolog
	ssh -t $FROM_SSH_REMOTE 'net start "Firebird Server - SiengeWEB"' | tolog
	sleep 5s
fi

echo $(nowstamp) Removing backups oldest than 30 | tolog
restic forget --keep-last 30 --prune | tolog

echo $(nowstamp) Unmounting unit $FROM_MOUNT_PATH | tolog
fusermount -u $FROM_MOUNT_PATH | tolog

echo $(nowstamp) End of the script $SCRIPT_PREFIX | tolog

