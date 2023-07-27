#!/bin/bash
# Run this script to backup dabatase and files from AWS EC2 site.
# REQUIRED: run this as sudo (administrator)
# REQUIRED: rclone configured to access remote files (ssh/sftp)
# REQUIRED: ssh credentials in ~/.ssh/config to `aws.cpn.com.br`

LOG_FILE="/var/lib/docker/volumes/log/_data/backup/site-aws.cpn.com.br.log"
CURRENT="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P)"
RCONFIG="$CURRENT/rclone.conf"


# Function to print timestamp in every step below
nowstamp() {
        echo $(date "+%Y/%m/%d %H:%M:%S")
}
printf "\n\n" >> $LOG_FILE
echo $(nowstamp) Starting alfresco.bkp.full.aws.fast.sh...>> $LOG_FILE


# Scheduling this script in cron
echo $(nowstamp) Creating/Updating cron file >> $LOG_FILE
CRON_NAME=/etc/cron.d/site-aws-cpn-com-br-backup
# Run at 5AM on Saturday (6)
echo "00 05 * * 6 root $CURRENT/site-aws.cpn.com.br-backup.sh 2>&1" > $CRON_NAME
chmod 0600 $CRON_NAME


FILESTAMP=`date "+%Y%m%d-%H%M%S"`
RMT_SERVER=aws.cpn.com.br
RMT_BKP_PATH="/home/ubuntu"
RMT_SITE_PATH="/var/www/cpn.com.br"
#SITE_BKP="cpn.com.br-${FILESTAMP}-files.tar.gz"
TO_PREFIX="/archive/full/site-aws.cpn.com.br/${FILESTAMP}"


echo $(nowstamp) Site Database - start >> $LOG_FILE
echo $(nowstamp) Database backup storing in remote... >> $LOG_FILE
DB_BKP="cpn.com.br-${FILESTAMP}-database.sql"
DB_NAME="cpn11"
DB_USER="cpn11"
# Your password will be prompted on screen
DB_PASS="CpnPl@an0201"

ssh -t $RMT_SERVER "mysqldump -u $DB_USER -p$DB_PASS --skip-extended-insert $DB_NAME > ${RMT_BKP_PATH}/${DB_BKP}"
echo "Database dumped to " \"${RMT_BKP_PATH}/${DB_BKP}\" >> $LOG_FILE

FROM="site-aws-cpn-com-br:${RMT_BKP_PATH}/${DB_BKP}"
TO="${TO_PREFIX}/db/"
mkdir --parents $TO

rclone sync $FROM $TO --progress \
--fast-list \
--delete-after --create-empty-src-dirs --delete-excluded \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line

echo $(nowstamp) Deleting database dump from remote...>> $LOG_FILE
ssh -t $RMT_SERVER "rm ${RMT_BKP_PATH}/${DB_BKP}" >> $LOG_FILE
echo $(nowstamp) Site Database  - finish >> $LOG_FILE



echo $(nowstamp) Site CPN Files - start >> $LOG_FILE
FROM="site-aws-cpn-com-br:${RMT_SITE_PATH}/"
TO="${TO_PREFIX}/files/"
rclone sync $FROM $TO --progress \
--fast-list \
--delete-after --create-empty-src-dirs --delete-excluded \
--log-file=$LOG_FILE --log-level=NOTICE --stats-log-level=NOTICE --config=$RCONFIG
head -n -1 $LOG_FILE > temp; mv temp $LOG_FILE #remove last empty line
echo $(nowstamp) Site CPN Files - finish >> $LOG_FILE

#Remove all directories except the 4 newest
echo $(nowstamp) Removing all backup directories, except the 4 newest >> $LOG_FILE
ls -dt /archive/full/site-aws.cpn.com.br/*/ | tail -n +5 | xargs rm -r >> $LOG_FILE
# ls -d ...*/ list directories, -t list them in them in order
# tail -n +5 prints all but the last four lines
# xargs rmdir calls rm -rm on each of those dirs (or you can use rm -r) if they non-empty
# Reference: https://stackoverflow.com/questions/45355305
	
echo $(nowstamp) "Done! Database and Files of cpn.com.br backuped! >> $LOG_FILE
