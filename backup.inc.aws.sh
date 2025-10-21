#!/bin/bash

SCRIPT_PREFIX="backup.inc.aws.sh"
SCRIPT_PATH="/app"

# `scriptname.sh` uses defaut 7168 KB/s (7MB/s) = 56Mbps
# `scriptname.sh --limit-download=0 --limit-upload=0` uses all available band
# `scriptname.sh --limit-download=20480` uses 20580 KB/s (20MB/s) = 160Mbps
# `scriptname.sh --stop-services` stops and restart the services before backup

cd $SCRIPT_PATH

source ./functions.sh

LOG=./logs/alfresco.bkp.$(date "+%Y.%m").log
mkdir -p ./logs && touch $LOG

printf "\n\n\n\n------------------------------------------------------------------------------------\n" >> $LOG
echo $(nowstamp) Script started: $SCRIPT_PREFIX >> $LOG
printf $(nowstamp) "Flags: \n--limit-download=$LIMIT_DOWNLOAD \n--limit-upload=$LIMIT_UPLOAD \n--stop-services=$STOP \n--update-cron=$UPDATE_CRON \n$SIZE_ONLY \n" 2>&1 | tolog

# STOP ALFRESCO
if [ $STOP == true ]; then
	echo "$(nowstamp) Stopping Alfresco application container..." 2>&1 | tolog
	docker stop alfresco2017_community 2>&1 | tolog
	echo "Awaiting 10s for graceful shutdown..." | tolog
	sleep 10s
fi


## DATABASE
echo $(nowstamp) Alfresco Database Backup... 2>&1 | tolog
DUMP_FILE="/srv/data/alfresco-db.sql"

# A variável ALFRESCO_DB_PASSWORD é exportada pelo entrypoint.sh
# Deixamos o restic gerenciar a compressão para maximizar a desduplicação.
echo "$(nowstamp) Creating database dump..." 2>&1 | tolog
PGPASSWORD=$ALFRESCO_DB_PASSWORD pg_dump -h $ALFRESCO_DB_HOST -U $ALFRESCO_DB_USER -d $ALFRESCO_DB_NAME --clean > $DUMP_FILE

echo "$(nowstamp) Backing up database dump with restic..." 2>&1 | tolog
restic backup $DUMP_FILE \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 \
  2>&1 | tolog

echo "$(nowstamp) Removing temporary dump file..." 2>&1 | tolog
rm $DUMP_FILE 2>&1 | tolog


# REPOSITORY - CONTENTSTORE
FROM=/srv/data/alfresco-community/alf_data/contentstore/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 \
  2>&1 | tolog

# REPOSITORY - TRASH (contentstore.deleted)
FROM=/srv/data/alfresco-community/alf_data/contentstore.deleted/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 \
  2>&1 | tolog

# REPOSITORY KEYSTORE
FROM=/srv/data/alfresco-community/alf_data/keystore/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 \
  2>&1 | tolog

# SEARCH INDEXES
FROM=/srv/data/alfresco-community/alf_data/solr4/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
 	--limit-download $LIMIT_DOWNLOAD \
 	--no-scan \
 	--verbose 0 \
   2>&1 | tolog

FROM=/srv/data/alfresco-infra
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 \
	--exclude-file="/srv/data/alfresco-infra/backup/.restic-exclude" \
  2>&1 | tolog


# APLICAÇÕES QUE NÃO ENVOLVEM SÓ O ALFRESCO

FROM=/srv/data/http-proxy
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 \
  2>&1 | tolog

FROM=/srv/data/backup-all
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 \
  2>&1 | tolog

# START ALFRESCO
if [ $STOP == true ]; then
	echo "$(nowstamp) Starting Alfresco application container..." 2>&1 | tolog
	docker start alfresco2017_community 2>&1 | tolog
fi

# KEEP LAST 30
echo $(nowstamp) A aplicar política de retenção... 2>&1 | tolog
restic forget \
	--keep-tag forever \
	--keep-last 70 \
	--keep-weekly 4 \
  --keep-monthly 12 \
  --keep-yearly 5 \
	--prune

echo $(nowstamp) End of the script $SCRIPT_PREFIX 2>&1 | tolog
