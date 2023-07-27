#!/bin/bash

SCRIPT_PREFIX="alfresco.bkp.full.aws.sh"

# `scriptname.sh` uses defaut 7168 KB/s (7MB/s) = 56Mbps
# `scriptname.sh --bwlimit=0` uses all available band
# `scriptname.sh --bwlimit=20480` uses 20580 KB/s (20MB/s) = 160Mbps
# `scriptname.sh --stop` stops and restart the services before backup
# `scriptname.sh --update-cron` to update cron.d with the current script

source ./.alfresco.aws.env
source ./functions.sh

#LOG="/var/lib/docker/volumes/log/_data/backup/alfresco.bkp.full.aws.log"
LOG=~/logs/sienge.bkp.$(date "+%Y.%m").log
mkdir -p ~/logs && touch $LOG

# FROM_RCLONE_REMOTE=linux-cpn-com-br
# FROM_SSH_REMOTE=linux.cpn.com.br
# FROM_REMOTE_PATH=/opt/alfresco-community
FROM_MOUNT_PATH=/opt/alfresco-community
TO_RCLONE_REMOTE=s3-bkp
TO_S3_BUCKET=cpn-alfresco-bkp-full
DB_LOCAL="/opt/alfresco-community/postgresql"

printf "\n\n" >> $LOG
echo $(nowstamp) Script started: $SCRIPT_PREFIX >> $LOG


if [ $UPDATE_CRON == true ]; then
  echo $(nowstamp) Creating/Updating cron file | tolog
  CRON_NAME=/etc/cron.d/alfresco-bkp-full-aws-fast
  # Run at 3AM on Tuesday (2), Thursday (4) and Saturday (6)
  echo "00 03 * * 2,4,6 root $CURRENT/$SCRIPT_PREFIX 2>&1" > $CRON_NAME
  chmod 0600 $CRON_NAME
fi

if [ $STOP == true ]; then
	echo "$(nowstamp) Stopping Alfresco Service" | tolog
	ssh $FROM_SSH_REMOTE "service alfresco stop" | tolog
	echo "$(nowstamp) Restart Alfresco Database..." | tolog
	ssh $FROM_SSH_REMOTE "$DB_LOCAL/scripts/ctl.sh start" | tolog
fi


echo $(nowstamp) Alfresco Database - start | tolog
FROM="$CURRENT/alfresco-db.sql"
echo $(nowstamp) "Database Dump..." | tolog
PG_URI=postgresql://${ALFRESCO_DB_USER}:${ALFRESCO_DB_PASSWORD}@${ALFRESCO_DB_HOST}:${ALFRESCO_DB_PORT}/${ALFRESCO_DB_NAME}
ssh $FROM_SSH_REMOTE "${DB_LOCAL}/bin/pg_dump $PG_URI" > $FROM | tolog

TO="$TO_RCLONE_REMOTE:$TO_S3_BUCKET/db/"
rclone sync $FROM $TO --progress \
--fast-list \
--bwlimit $BWLIMIT \
--delete-after --delete-excluded \
--log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE
head -n -1 $LOG > temp; mv temp $LOG #remove last empty line 
rm $FROM
echo $(nowstamp) Alfresco Database - finish | tolog


echo $(nowstamp) Alfresco Repository - start | tolog
FROM="$FROM_MOUNT_PATH/alf_data/contentstore/"
TO="$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/alf_data/contentstore/"
rclone sync $FROM $TO --progress \
--fast-list --size-only \
--bwlimit $BWLIMIT \
--delete-after --create-empty-src-dirs --delete-excluded \
--log-file=$LOG --log-level=NOTICE --stats-log-level NOTICE
head -n -1 $LOG > temp; mv temp $LOG #remove last empty line
echo $(nowstamp) Alfresco Repository - finish | tolog

echo $(nowstamp) Alfresco Trash - start | tolog
FROM="$FROM_MOUNT_PATH/alf_data/contentstore.deleted/"
TO="$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/alf_data/contentstore.deleted/"
rclone sync $FROM $TO --progress \
--fast-list --size-only \
--bwlimit $BWLIMIT \
--delete-after --create-empty-src-dirs \
--log-file=$LOG --log-level=NOTICE --stats-log-level NOTICE
head -n -1 $LOG > temp; mv temp $LOG #remove last empty line
echo $(nowstamp) Alfresco Trash - finish | tolog

echo $(nowstamp) Alfresco Search Index - start | tolog
FROM="$FROM_MOUNT_PATH/alf_data/solr4/" 
TO="$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/alf_data/solr4/"
rclone sync $FROM $TO --progress \
--fast-list --size-only \
--bwlimit $BWLIMIT \
--delete-after --create-empty-src-dirs \
--log-file=$LOG --log-level=NOTICE --stats-log-level NOTICE
head -n -1 $LOG > temp; mv temp $LOG #remove last empty line 
echo $(nowstamp) Alfresco Search Index - finish | tolog




echo $(nowstamp) Alfresco App Settings - start >> $LOG
FROM="/opt/alfresco-community/"
echo "tomcat/shared/classes/alfresco-global.properties" > files.txt
echo "tomcat/conf/server.xml" >> files.txt
echo "tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml" >> files.txt
echo "solr4/archive-SpacesStore/conf/solrcore.properties" >> files.txt
echo "solr4/workspace-SpacesStore/conf/solrcore.properties" >> files.txt
TO="$TO_RCLONE_REMOTE:$TO_S3_BUCKET/full/alfresco/app_settings/"
rclone sync $FROM $TO --include-from=files.txt --progress \
--bwlimit 7M \
--delete-after --delete-excluded --create-empty-src-dirs \
--log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG > temp; mv temp $LOG #remove last empty line
rm files.txt
echo $(nowstamp) Alfresco AppSettings - finish >> $LOG



echo $(nowstamp) Alfresco App Settings - start | tolog
rclone copy "/opt/alfresco-community/tomcat/shared/classes/alfresco-global.properties" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/tomcat/shared/classes/alfresco-global.properties" \
  --progress -log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $BWLIMIT
rclone copy "/opt/alfresco-community/tomcat/conf/server.xml" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/tomcat/conf/server.xml" \
  --progress -log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $BWLIMIT
rclone copy "/opt/alfresco-community/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml" \
  --progress -log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $BWLIMIT
rclone copy "/opt/alfresco-community/solr4/archive-SpacesStore/conf/solrcore.properties" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/solr4/archive-SpacesStore/conf/solrcore.properties" \
  --progress -log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $BWLIMIT
rclone copy "/opt/alfresco-community/solr4/workspace-SpacesStore/conf/solrcore.properties" \
  "$TO_RCLONE_REMOTE:$TO_S3_BUCKET/opt/alfresco-community/solr4/workspace-SpacesStore/conf/solrcore.properties" \
  --progress -log-file=$LOG --log-level=NOTICE --stats-log-level=NOTICE --bwlimit $BWLIMIT
echo $(nowstamp) Alfresco AppSettings - finish | tolog


if [ $STOP == true ]; then
	echo "$(nowstamp) Starting Alfresco Service..." | tolog
	ssh $FROM_SSH_REMOTE "service alfresco start" | tolog
fi


echo $(nowstamp) End of the script $SCRIPT_PREFIX | tolog