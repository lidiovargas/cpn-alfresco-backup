LOG_FILE="/var/lib/docker/volumes/log/_data/backup/alfresco.bkp.full.local.log"
DB_LOCAL="/opt/alfresco-community/postgresql"
CURRENT="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)" 
RCONFIG="$CURRENT/rclone.conf"

nowstamp() {  
	echo $(date "+%Y/%m/%d %H:%M:%S")  
}
printf "\n\n" >> $LOG_FILE

echo $(nowstamp) Creating/Updating cron file >> $LOG_FILE
CRON_NAME=/etc/cron.d/alfresco-bkp-full-local
# Run at 2AM every day
echo "00 02 * * * root $CURRENT/alfresco.bkp.full.local.sh 2>&1" > $CRON_NAME
chmod 0600 $CRON_NAME

if [ "$1" != "--dont-stop-services" ]; then
	echo "$(nowstamp) Stopping Alfresco Service" >> $LOG_FILE
	service alfresco stop >> $LOG_FILE
	echo "$(nowstamp) Restart Alfresco Database..." >> $LOG_FILE
	$DB_LOCAL/scripts/ctl.sh start $LOG_FILE
fi

echo $(nowstamp) Alfresco Database - start >> $LOG_FILE
FROM="$CURRENT/alfresco-db.sql"
echo $(nowstamp) "Database Dump..." >> $LOG_FILE
${DB_LOCAL}/bin/pg_dump -h localhost -p 5432 -Ualfresco alfresco > $FROM 
TO="/archive/full/alfresco/db/"
rclone sync $FROM $TO --progress --delete-before --create-empty-src-dirs --delete-excluded \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line 
rm $FROM
echo $(nowstamp) Alfresco Database - finish >> $LOG_FILE


echo $(nowstamp) Alfresco Repository - start >> $LOG_FILE
FROM="/opt/alfresco-community/alf_data/contentstore/" 
TO="/archive/full/alfresco/repository/"
rclone sync $FROM $TO --progress --delete-before --create-empty-src-dirs \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line
echo $(nowstamp) Alfresco Repository - finish >> $LOG_FILE

echo $(nowstamp) Alfresco Trash - start >> $LOG_FILE
FROM="/opt/alfresco-community/alf_data/contentstore.deleted/" 
TO="/archive/full/alfresco/repository.trash/"
rclone sync $FROM $TO --progress --delete-before --create-empty-src-dirs \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line
echo $(nowstamp) Alfresco Trash - finish >> $LOG_FILE

echo $(nowstamp) Alfresco Search Index - start >> $LOG_FILE
FROM="/opt/alfresco-community/alf_data/solr4" 
TO="/archive/full/alfresco/search/"
rclone sync $FROM $TO --progress --delete-before --create-empty-src-dirs \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line 
echo $(nowstamp) Alfresco Search Index - finish >> $LOG_FILE


echo $(nowstamp) Alfresco Logs - start >> $LOG_FILE
FROM="/opt/alfresco-community/"
echo "alfresco.log**" > files.txt
echo "share.log**" >> files.txt
echo "solr.log**" >> files.txt
echo "tomcat/logs/**" >> files.txt
TO="/archive/full/alfresco/logs/"
# DANGEROUS: Remove logs older than +30 days - Comment this lines if not sure
find $FROM -maxdepth 1 -type f \( -name "alfresco.log*" -o -name "share.log*" \
-o -name "solr.log*" \) -mtime +30 -delete
find ${FROM}tomcat/logs/* -maxdepth 1 -type f -mtime +7 -delete 
# SYNC LOGS:
rclone sync $FROM --include-from=files.txt $TO --progress \
--delete-before --delete-excluded --create-empty-src-dirs \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line
rm files.txt
echo $(nowstamp) Alfresco Logs - finish >> $LOG_FILE


if [ "$1" != "--dont-stop-services" ]; then
	echo "$(nowstamp) Starting Alfresco Service..." >> $LOG_FILE
	service alfresco start >> $LOG_FILE
fi


echo $(nowstamp) Alfresco App Settings - start >> $LOG_FILE
FROM="/opt/alfresco-community/"
echo "tomcat/shared/classes/alfresco-global.properties" > files.txt
echo "tomcat/conf/server.xml" >> files.txt
echo "tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml" >> files.txt
echo "solr4/archive-SpacesStore/conf/solrcore.properties" >> files.txt
echo "solr4/workspace-SpacesStore/conf/solrcore.properties" >> files.txt
TO="/archive/full/alfresco/app_settings/"
rclone sync $FROM $TO --include-from=files.txt --progress \
--delete-before --delete-excluded --create-empty-src-dirs \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line 
rm files.txt
echo $(nowstamp) Alfresco AppSettings - finish >> $LOG_FILE



echo $(nowstamp) Alfresco OS Settings - start >> $LOG_FILE
FROM="/"
echo "/etc/init.d/alfresco" >> files.txt
echo "/etc/letsencrypt/live/alfresco.cpn.com.br/*" >> files.txt
echo "/home/lidio/dev/monitor/alfresco-certs.sh" >> files.txt
echo "/home/lidio/dev/monitor/timestamp.sh" >> files.txt
echo "/etc/cron.d/alfresco-certs-cron" >> files.txt
echo "/etc/cron.d/alfresco-bkp-full-local" >> files.txt
echo "/etc/cron.d/alfresco-bkp-full-aws-fast" >> files.txt
echo "/etc/cron.d/alfresco-bkp-full-aws-slow"  >> files.txt
echo "/home/lidio/bkp/alfresco.bkp.full.local.sh" >> files.txt
echo "/home/lidio/bkp/alfresco.bkp.full.aws.fast.sh" >> files.txt
echo "/home/lidio/bkp/alfresco.bkp.full.aws.slow.sh" >> files.txt
echo "/home/lidio/bkp/rclone.conf" >> files.txt
# The operation "rclone sync..." bellow fails in  "local:" to "local: environments"
# and needs "empty dest folder" and "rclone copy..." instead
# On "local:" to "remote:" try with "rclone sync..." instead 
TO="/archive/full/alfresco/os_settings/"
### WARNING: Dangerous command if $TO is "/"
rm ${TO}* -rf 
rclone copy $FROM ${TO} --include-from=files.txt --progress \
--copy-links \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line 
rm files.txt
echo $(nowstamp) Alfresco OS Settings - finish >> $LOG_FILE
