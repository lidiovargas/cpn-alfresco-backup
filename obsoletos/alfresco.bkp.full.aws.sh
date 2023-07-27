#!/bin/bash

SCRIPT_PREFIX="alfresco.bkp.full.aws.sh"

# `scriptname.sh` uses defaut 7168 KB/s (7MB/s) = 56Mbps
# `scriptname.sh --limit-download=0 --limit-upload=0` uses all available band
# `scriptname.sh --limit-download=20480` uses 20580 KB/s (20MB/s) = 160Mbps
# `scriptname.sh --stop-services` stops and restart the services before backup
# `scriptname.sh --update-cron` to update cron.d with the current script
# `scriptname.sh --size-only-off` disable --size-only checks on rclone for AWS S3 = slowest result

source ./.alfresco.full.aws.env
source ./functions.sh

LOG=~/logs/alfresco.bkp.$(date "+%Y.%m").log
mkdir -p ~/logs && touch $LOG

printf "\n\n" >> $LOG
echo $(nowstamp) Script started: $SCRIPT_PREFIX >> $LOG
printf $(nowstamp) "Flags: \n--limit-download=$LIMIT_DOWNLOAD \n--limit-upload=$LIMIT_UPLOAD \n--stop-services=$STOP \n--update-cron=$UPDATE_CRON \n$SIZE_ONLY" | tolog

# Update cron schedule
if [ $UPDATE_CRON == true ]; then
  echo $(nowstamp) Creating/Updating cron file | tolog
  CRON_NAME=/etc/cron.d/alfresco-bkp-full-aws 
  
  # Run at 3AM on Tuesday (2), Thursday (4) and Saturday (6)
  echo "00 03 * * 2,4,6 root $CURRENT/$SCRIPT_PREFIX --stop-services --limit-download=0 --limit-upload=0 2>&1" > $CRON_NAME
  
  # Run ao 4AM on the first Sunday of every month
  echo "00 04  * * 0 root  [ \"\$(date +\%d)\" -le 7 ] &&  $CURRENT/$SCRIPT_PREFIX --stop-services --size-only-off --limit-download=0 --limit-upload=0 2>&1" > $CRON_NAME

  chmod 600 $CRON_NAME
fi

# Stop Alfresco
if [ $STOP == true ]; then
	echo "$(nowstamp) Stopping Alfresco Service" | tolog
	ssh $FROM_SSH_REMOTE "service alfresco stop" | tolog
	echo "$(nowstamp) Restart Alfresco Database..." | tolog
	ssh $FROM_SSH_REMOTE "$FROM_DB_LOCAL/scripts/ctl.sh start" | tolog
  sleep 10s
fi

# DATABASE
echo $(nowstamp) Alfresco Database - start | tolog
FROM="$CURRENT/alfresco-db.sql"
echo $(nowstamp) "Database Dump..." | tolog
PG_URI=postgresql://${ALFRESCO_DB_USER}:${ALFRESCO_DB_PASSWORD}@${ALFRESCO_DB_HOST}:${ALFRESCO_DB_PORT}/${ALFRESCO_DB_NAME}
ssh $FROM_SSH_REMOTE "${FROM_DB_LOCAL}/bin/pg_dump $PG_URI" > $FROM | tolog

TO="$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/db/"
rclone sync $FROM $TO --progress \
--fast-list \
--bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD \
--delete-after --delete-excluded \
--log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE
head -n -1 $LOG > temp; mv temp $LOG #remove last empty line 
rm $FROM
echo $(nowstamp) Alfresco Database - finish | tolog

# MOUNT UNIT
if [ $FROM_MOUNT == true ]; then
  echo $(nowstamp) Mounting unit $FROM_LOCAL_PATH | tolog
  rclone mount $FROM_RCLONE_REMOTE:$FROM_REMOTE_PATH $FROM_LOCAL_PATH \ 
  --daemon \
  --bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD \
  | tolog
fi

# REPOSITORY
echo $(nowstamp) Alfresco Repository - start | tolog
FROM="$FROM_LOCAL_PATH/alf_data/contentstore/"
TO="$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/alf_data/contentstore/"
rclone sync $FROM $TO --progress \
--fast-list $SIZE_ONLY \
--bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD \
--delete-after --delete-excluded \
--log-file=$LOG --log-level=NOTICE --stats-log-level NOTICE
head -n -1 $LOG > temp; mv temp $LOG #remove last empty line
echo $(nowstamp) Alfresco Repository - finish | tolog

# REPOSITORY TRASH
echo $(nowstamp) Alfresco Trash - start | tolog
FROM="$FROM_LOCAL_PATH/alf_data/contentstore.deleted/"
TO="$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/alf_data/contentstore.deleted/"
rclone sync $FROM $TO --progress \
--fast-list $SIZE_ONLY \
--bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD \
--delete-after --create-empty-src-dirs \
--log-file=$LOG --log-level=NOTICE --stats-log-level NOTICE
head -n -1 $LOG > temp; mv temp $LOG #remove last empty line
echo $(nowstamp) Alfresco Trash - finish | tolog

# SEARCH INDEX
echo $(nowstamp) Alfresco Search Index - start | tolog
FROM="$FROM_LOCAL_PATH/alf_data/solr4/" 
TO="$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/alf_data/solr4/"
rclone sync $FROM $TO --progress \
--fast-list $SIZE_ONLY \
--bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD \
--delete-after --create-empty-src-dirs \
--log-file=$LOG --log-level=NOTICE --stats-log-level NOTICE
head -n -1 $LOG > temp; mv temp $LOG #remove last empty line 
echo $(nowstamp) Alfresco Search Index - finish | tolog

# IMPORTANT SETTINGS
echo $(nowstamp) Alfresco App Settings - start | tolog
rclone copy "/opt/alfresco-community/tomcat/shared/classes/alfresco-global.properties" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/tomcat/shared/classes/" \
  --create-empty-src-dirs \
  --progress --log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD
rclone copy "/opt/alfresco-community/tomcat/conf/server.xml" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/tomcat/conf/" \
  --create-empty-src-dirs \
  --progress --log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD
rclone copy "/opt/alfresco-community/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/tomcat/shared/classes/alfresco/web-extension/" \
  --create-empty-src-dirs \
  --progress --log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD
rclone copy "/opt/alfresco-community/solr4/archive-SpacesStore/conf/solrcore.properties" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/solr4/archive-SpacesStore/conf/" \
  --create-empty-src-dirs \
  --progress --log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD
rclone copy "/opt/alfresco-community/solr4/workspace-SpacesStore/conf/solrcore.properties" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/solr4/workspace-SpacesStore/conf/" \
  --create-empty-src-dirs \
  --progress --log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD
echo $(nowstamp) Alfresco AppSettings - finish | tolog

# START ALFRESCO
if [ $STOP == true ]; then
	echo "$(nowstamp) Starting Alfresco Service..." | tolog
	ssh $FROM_SSH_REMOTE "service alfresco start" | tolog
fi

# UNMOUNT UNIT
if [ $FROM_MOUNT == true ]; then
  echo $(nowstamp) Unmounting unit $FROM_LOCAL_PATH | tolog
  fusermount -u $FROM_LOCAL_PATH | tolog
fi


echo $(nowstamp) End of the script $SCRIPT_PREFIX | tolog