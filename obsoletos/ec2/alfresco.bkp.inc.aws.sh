#!/bin/bash

SCRIPT_PREFIX="alfresco.bkp.inc.sh"

# `scriptname.sh` uses defaut 7168 KB/s (7MB/s) = 56Mbps
# `scriptname.sh --limit-download=0 --limit-upload=0` uses all available band
# `scriptname.sh --limit-download=20480` uses 20580 KB/s (20MB/s) = 160Mbps
# `scriptname.sh --stop-services` stops and restart the services before backup
# `scriptname.sh --update-cron` to update cron.d with the current script
# `scriptname.sh --size-only-off` disable --size-only checks on rclone for AWS S3 = slowest result

source ./.alfresco.inc.env
source ./functions.sh

LOG=~/logs/alfresco.bkp.$(date "+%Y.%m").log
mkdir -p ~/logs && touch $LOG

printf "\n\n" >> $LOG
echo $(nowstamp) Script started: $SCRIPT_PREFIX >> $LOG
printf $(nowstamp) "Flags: \n--limit-download=$LIMIT_DOWNLOAD \n--limit-upload=$LIMIT_UPLOAD \n--stop-services=$STOP \n--update-cron=$UPDATE_CRON \n$SIZE_ONLY" | tolog

# UPDATE CRON SCHEDULE
if [ $UPDATE_CRON == true ]; then
  echo $(nowstamp) Creating/Updating cron file | tolog
  CRON_NAME=/etc/cron.d/alfresco-bkp-inc-aws
  # Run at 3AM on Tuesday (2), Thursday (4) and Saturday (6)
  echo "00 01 * * 2,4,6 root $CURRENT/$SCRIPT_PREFIX --limit-download=0 --limit-upload=0 2>&1" > $CRON_NAME
  chmod 0600 $CRON_NAME
fi

# STOP ALFRESCO
if [ $STOP == true ]; then
	echo "$(nowstamp) Stopping Alfresco Service" | tolog
	ssh $FROM_SSH_REMOTE "service alfresco stop" | tolog
	echo "$(nowstamp) Restart Alfresco Database..." | tolog
	ssh $FROM_SSH_REMOTE "$DB_LOCAL/scripts/ctl.sh start" | tolog
	sleep 10s
fi

# MOUNT UNIT
if [ $FROM_MOUNT == true ]; then
  echo $(nowstamp) Mounting unit $FROM_LOCAL_PATH | tolog
  rclone mount $FROM_RCLONE_REMOTE:$FROM_REMOTE_PATH $FROM_LOCAL_PATH \
  --daemon \
  --bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD \
	--vfs-cache-mode=writes \
	| tolog
fi



# REPOSITORY
FROM=${FROM_LOCAL_PATH}/alf_data/contentstore
echo $(nowstamp) Backup $FROM/ | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
	-o rest.connections=20 \
  | tolog

# # SETTINGS
# FROM=${FROM_LOCAL_PATH}/tomcat/shared/classes/alfresco-global.properties
# echo $(nowstamp) Backup $FROM | tolog
# restic backup $FROM \
# 	--limit-upload $LIMIT_UPLOAD \
# 	--limit-download $LIMIT_DOWNLOAD \
# 	--verbose 0 \
# 	--no-scan \
#   | tolog

# FROM=${FROM_LOCAL_PATH}/tomcat/conf/server.xml
# echo $(nowstamp) Backup $FROM | tolog
# restic backup $FROM \
# 	--limit-upload $LIMIT_UPLOAD \
# 	--limit-download $LIMIT_DOWNLOAD \
# 	--verbose 0 \
# 	--no-scan \
#   | tolog

# FROM=${FROM_LOCAL_PATH}/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml
# echo $(nowstamp) Backup $FROM | tolog
# restic backup $FROM \
# 	--limit-upload $LIMIT_UPLOAD \
# 	--limit-download $LIMIT_DOWNLOAD \
# 	--verbose 0 \
# 	--no-scan \
#   | tolog

# FROM=${FROM_LOCAL_PATH}/solr4/archive-SpacesStore/conf/solrcore.properties
# echo $(nowstamp) Backup $FROM | tolog
# restic backup $FROM \
# 	--limit-upload $LIMIT_UPLOAD \
# 	--limit-download $LIMIT_DOWNLOAD \
# 	--verbose 2 \
#    2>> $LOG

# FROM=${FROM_LOCAL_PATH}/solr4/workspace-SpacesStore/conf/solrcore.properties
# echo $(nowstamp) Backup $FROM | tolog
# restic backup $FROM \
# 	--limit-upload $LIMIT_UPLOAD \
# 	--limit-download $LIMIT_DOWNLOAD \
# 	--verbose 0 \
# 	--no-scan \
#   | tolog

# # REPOSITORY TRASH
# FROM=${FROM_LOCAL_PATH}/alf_data/contentstore.deleted/
# echo $(nowstamp) Backup $FROM | tolog
# restic backup $FROM \
# 	--limit-upload $LIMIT_UPLOAD \
# 	--limit-download $LIMIT_DOWNLOAD \
# 	--verbose 0 \
# 	--no-scan \
#   | tolog

# # SEARCH INDEXES
# FROM=${FROM_LOCAL_PATH}/alf_data/sorl4/
# echo $(nowstamp) Backup $FROM | tolog
# restic backup $FROM \
# 	--limit-upload $LIMIT_UPLOAD \
# 	--limit-download $LIMIT_DOWNLOAD \
# 	--verbose 0 \
# 	--no-scan \
#   | tolog


# TODO DATABASE???
# TODO tree from webdav or smb mounted unit

# START ALFRESCO
if [ $STOP == true ]; then
	echo "$(nowstamp) Starting Alfresco Service..." | tolog
	ssh $FROM_SSH_REMOTE "service alfresco start" | tolog
	# sleep 5s
fi

# UNMOUNT UNIT
if [ $FROM_MOUNT == true ]; then
  echo $(nowstamp) Unmounting unit $FROM_LOCAL_PATH | tolog
  fusermount -u $FROM_LOCAL_PATH | tolog
fi


# # KEEP LAST 30
# echo $(nowstamp) Removing backups oldest than 30 | tolog
# restic forget --keep-tag forever --keep-last 30 --prune | tolog


echo $(nowstamp) End of the script $SCRIPT_PREFIX | tolog
