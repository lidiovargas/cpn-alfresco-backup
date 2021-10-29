LOG_FILE="/var/lib/docker/volumes/log/_data/backup/alfresco.bkp.full.aws.log"
CURRENT="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
RCONFIG="$CURRENT/rclone.conf"

nowstamp() {  
	echo $(date "+%Y/%m/%d %H:%M:%S")  
}
printf "\n\n" >> $LOG_FILE
echo $(nowstamp) Starting alfresco.bkp.full.aws.fast.sh...>> $LOG_FILE


echo $(nowstamp) Creating/Updating cron file >> $LOG_FILE
CRON_NAME=/etc/cron.d/alfresco-bkp-full-aws-fast
# Run at 3AM on Tuesday (2), Thursday (4) and Saturday (6)
echo "00 03 * * 2,4,6 root $CURRENT/alfresco.bkp.full.aws.fast.sh 2>&1" > $CRON_NAME
chmod 0600 $CRON_NAME


echo $(nowstamp) Alfresco Database - start >> $LOG_FILE
FROM="/archive/full/alfresco/db/"
TO="s3-bkp:backup-cpn/full/alfresco/db/"
rclone sync $FROM $TO --progress \
--fast-list \
--delete-after --create-empty-src-dirs --delete-excluded \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line 
echo $(nowstamp) Alfresco Database - finish >> $LOG_FILE

echo $(nowstamp) Alfresco Repository - start >> $LOG_FILE
FROM="/archive/full/alfresco/repository/"
TO="s3-bkp:backup-cpn/full/alfresco/repository/"
rclone sync $FROM $TO --progress \
--fast-list --size-only \
--delete-after --create-empty-src-dirs --delete-excluded \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line
echo $(nowstamp) Alfresco Repository - finish >> $LOG_FILE

echo $(nowstamp) Alfresco Trash - start >> $LOG_FILE
FROM="/archive/full/alfresco/repository.trash/"
TO="s3-bkp:backup-cpn/full/alfresco/repository.trash/"
rclone sync $FROM $TO --progress \
--fast-list --size-only \
--delete-after --create-empty-src-dirs \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line
echo $(nowstamp) Alfresco Trash - finish >> $LOG_FILE

echo $(nowstamp) Alfresco Search Index - start >> $LOG_FILE
FROM="/archive/full/alfresco/search/" 
TO="s3-bkp:backup-cpn/full/alfresco/search/"
rclone sync $FROM $TO --progress \
--fast-list --size-only \
--delete-after --create-empty-src-dirs \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line 
echo $(nowstamp) Alfresco Search Index - finish >> $LOG_FILE

echo $(nowstamp) Alfresco Logs - start >> $LOG_FILE
FROM="/archive/full/alfresco/logs/"
TO="s3-bkp:backup-cpn/full/alfresco/logs/"
# SYNC LOGS:
rclone sync $FROM $TO --progress \
--fast-list --size-only \
--delete-after --create-empty-src-dirs --delete-excluded \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line
echo $(nowstamp) Alfresco Logs - finish >> $LOG_FILE


echo $(nowstamp) Alfresco App Settings - start >> $LOG_FILE
FROM="/archive/full/alfresco/app_settings/"
TO="s3-bkp:backup-cpn/full/alfresco/app_settings/"
rclone sync $FROM $TO --progress \
--fast-list \
--delete-after --create-empty-src-dirs --delete-excluded \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line
echo $(nowstamp) Alfresco AppSettings - finish >> $LOG_FILE


echo $(nowstamp) Alfresco OS Settings - start >> $LOG_FILE
FROM="/archive/full/alfresco/os_settings/"
TO="s3-bkp:backup-cpn/full/alfresco/app_settings/"
rclone sync $FROM ${TO} --progress \
--fast-list \
--delete-after --create-empty-src-dirs --delete-excluded \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line
echo $(nowstamp) Alfresco OS Settings - finish >> $LOG_FILE

