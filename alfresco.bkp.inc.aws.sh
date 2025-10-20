#!/bin/bash

SCRIPT_PREFIX="alfresco.bkp.inc.aws.sh"
SCRIPT_PATH="/opt/alfresco-backup"

# `scriptname.sh` uses defaut 7168 KB/s (7MB/s) = 56Mbps
# `scriptname.sh --limit-download=0 --limit-upload=0` uses all available band
# `scriptname.sh --limit-download=20480` uses 20580 KB/s (20MB/s) = 160Mbps
# `scriptname.sh --stop-services` stops and restart the services before backup
# `scriptname.sh --update-cron` to update cron.d with the current script
# `scriptname.sh --size-only-off` disable --size-only checks on rclone for AWS S3 = slowest result

cd $SCRIPT_PATH

source ./.alfresco.inc.env
source ./functions.sh

LOG=./logs/alfresco.bkp.$(date "+%Y.%m").log
mkdir -p ./logs && touch $LOG

printf "\n\n\n\n------------------------------------------------------------------------------------\n" >> $LOG
echo $(nowstamp) Script started: $SCRIPT_PREFIX >> $LOG
printf $(nowstamp) "Flags: \n--limit-download=$LIMIT_DOWNLOAD \n--limit-upload=$LIMIT_UPLOAD \n--stop-services=$STOP \n--update-cron=$UPDATE_CRON \n$SIZE_ONLY \n" 2>&1 | tolog

# UPDATE CRON SCHEDULE
if [ $UPDATE_CRON == true ]; then
  echo $(nowstamp) Creating/Updating cron file 2>&1 | tolog
  CRON_NAME=/etc/cron.d/alfresco-bkp-inc-aws
  # Run at 3AM on Tuesday (2), Thursday (4) and Saturday (6)
  echo "00 01 * * * root $SCRIPT_PATH/$SCRIPT_PREFIX --stop-services --limit-download=0 --limit-upload=0 2>&1" > $CRON_NAME
  chmod 0600 $CRON_NAME
fi

# STOP ALFRESCO
if [ $STOP == true ]; then
  if [ $FROM_MOUNT == true ]; then
	  echo "$(nowstamp) Stopping Alfresco Service" 2>&1 | tolog
	  ssh $FROM_SSH_REMOTE "service alfresco stop" 2>&1 | tolog
	  echo "Awaiting 120s..." | tolog
    sleep 120s
	  echo "$(nowstamp) Restart Alfresco Database..." 2>&1 | tolog
	  ssh $FROM_SSH_REMOTE "$FROM_DB_LOCAL/scripts/ctl.sh start" 2>&1 | tolog
	  echo "Awaiting 10s..." | tolog
    sleep 10s
  else
	  echo "$(nowstamp) Stopping Alfresco Service" 2>&1 | tolog
	  #service alfresco stop 2>&1 | tolog
	  #echo "Awaiting 120s..." | tolog
    #sleep 120s
	  #echo "$(nowstamp) Restart Alfresco Database..." 2>&1 | tolog
	  #$FROM_DB_LOCAL/scripts/ctl.sh start 2>&1 | tolog
    docker stop acs1 | tolog
	  echo "Awaiting 10s..." | tolog
    sleep 10s
  fi
fi

# MOUNT UNIT
if [ $FROM_MOUNT == true ]; then
  echo $(nowstamp) Mounting unit $FROM_LOCAL_PATH 2>&1 | tolog
  rclone mount $FROM_RCLONE_REMOTE:$FROM_REMOTE_PATH $FROM_LOCAL_PATH \
  --daemon \
  --bwlimit $LIMIT_UPLOAD:$LIMIT_DOWNLOAD \
	2>&1 | tolog
fi

## DATABASE
echo $(nowstamp) Alfresco Database Backup...2>&1 | tolog
FROM="$SCRIPT_PATH/alfresco-db.sql"
PG_URI=postgresql://${ALFRESCO_DB_USER}:${ALFRESCO_DB_PASSWORD}@${ALFRESCO_DB_HOST}:${ALFRESCO_DB_PORT}/${ALFRESCO_DB_NAME}

if [ $FROM_MOUNT == true ]; then
  # Quando rodar o script desde outro computador
  ssh $FROM_SSH_REMOTE "${FROM_DB_LOCAL}/bin/pg_dump --clean --if-exists $PG_URI" > $FROM 2>&1 | tolog
else
  # Quando rodar o script desde o computador local
  ${FROM_DB_LOCAL}/bin/pg_dump --clean --if-exists $PG_URI > $FROM 2>&1 | tolog
fi

restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

rm $FROM 2>&1 | tolog


# REPOSITORY
FROM=${FROM_LOCAL_PATH}/alf_data/contentstore
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

# REPOSITORY TRASH
FROM=${FROM_LOCAL_PATH}/alf_data/contentstore.deleted/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

 # SEARCH INDEXES
FROM=${FROM_LOCAL_PATH}/alf_data/solr4/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
 	--limit-download $LIMIT_DOWNLOAD \
 	--verbose 0 \
 	--no-scan \
   2>&1 | tolog

# SETTINGS
#FROM=${FROM_LOCAL_PATH}/tomcat/shared/classes/alfresco-global.properties
#echo $(nowstamp) Backup $FROM 2>&1 | tolog
#restic backup $FROM \
#	--limit-upload $LIMIT_UPLOAD \
#	--limit-download $LIMIT_DOWNLOAD \
#	--verbose 0 \
#	--no-scan \
#  2>&1 | tolog

#FROM=${FROM_LOCAL_PATH}/tomcat/conf/server.xml
#echo $(nowstamp) Backup $FROM 2>&1 | tolog
#restic backup $FROM \
#	--limit-upload $LIMIT_UPLOAD \
#	--limit-download $LIMIT_DOWNLOAD \
#	--verbose 0 \
#	--no-scan \
#  2>&1 | tolog

#FROM=${FROM_LOCAL_PATH}/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml
#echo $(nowstamp) Backup $FROM 2>&1 | tolog
#restic backup $FROM \
#	--limit-upload $LIMIT_UPLOAD \
#	--limit-download $LIMIT_DOWNLOAD \
#	--verbose 0 \
#	--no-scan \
#  2>&1 | tolog

#FROM=${FROM_LOCAL_PATH}/solr4/archive-SpacesStore/conf/solrcore.properties
#echo $(nowstamp) Backup $FROM 2>&1 | tolog
#restic backup $FROM \
#	--limit-upload $LIMIT_UPLOAD \
#	--limit-download $LIMIT_DOWNLOAD \
#	--verbose 2 \
#   2>> $LOG

#FROM=${FROM_LOCAL_PATH}/solr4/workspace-SpacesStore/conf/solrcore.properties
#echo $(nowstamp) Backup $FROM 2>&1 | tolog
#restic backup $FROM \
#	--limit-upload $LIMIT_UPLOAD \
#	--limit-download $LIMIT_DOWNLOAD \
#	--verbose 0 \
#	--no-scan \
#  2>&1 | tolog

# APLICAÇÕES SECUNDÁRIAS
#FROM=/opt/alfresco-tree
#echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
#restic backup ${FROM}/ \
#	--limit-upload $LIMIT_UPLOAD \
#	--limit-download $LIMIT_DOWNLOAD \
#	--verbose 0 \
#	--no-scan \
#  2>&1 | tolog

FROM=/opt/alfresco-backup
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

FROM=/opt/alfresco-restore
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

FROM=/opt/alfresco-projects-notification
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

FROM=/opt/alfresco-clean-hidden-files
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

FROM=/opt/alfresco-clean-index
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

FROM=/opt/alfresco-clean-log-files
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

FROM=/opt/alfresco-docker
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

FROM=/opt/alfresco-installers
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

# APLICAÇÕES QUE NÃO ENVOLVEM SÓ O ALFRESCO

FROM=/opt/http-proxy
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

#FROM=/opt/cert-monitor
#echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
#restic backup ${FROM}/ \
#	--limit-upload $LIMIT_UPLOAD \
#	--limit-download $LIMIT_DOWNLOAD \
#	--verbose 0 \
#	--no-scan \
#  2>&1 | tolog

FROM=/opt/backup-all
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--verbose 0 \
	--no-scan \
  2>&1 | tolog

# START ALFRESCO
if [ $STOP == true ]; then
  if [ $FROM_MOUNT == true ]; then
	  echo "$(nowstamp) Starting Alfresco Service..." 2>&1 | tolog
	  ssh $FROM_SSH_REMOTE "service alfresco start"  2>&1 | tolog
	  # sleep 5s
  else
	  echo "$(nowstamp) Starting Alfresco Service..." 2>&1 | tolog
	  #service alfresco start  2>&1 | tolog
    docker start acs1
	  # sleep 5s
  fi
fi

# UNMOUNT UNIT
if [ $FROM_MOUNT == true ]; then
  echo $(nowstamp) Unmounting unit $FROM_LOCAL_PATH 2>&1 | tolog
  fusermount -u $FROM_LOCAL_PATH 2>&1 | tolog
fi

# KEEP LAST 30
echo $(nowstamp) Removing backups oldest than 60 2>&1 | tolog
restic forget --keep-tag forever --keep-last 60 --prune

echo $(nowstamp) End of the script $SCRIPT_PREFIX 2>&1 | tolog
