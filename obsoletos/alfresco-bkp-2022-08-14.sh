#!/bin/bash
# Alfresco Backup script
#
# FROM: linux server, TO: remote server
# Only the diferents files of the period
#
# To non-interactive mode of password, create
# a "sudo ~/.pgass" or literally "/root/.pgpass"
# with the string of your conection, in the format:
#      hostname:port:database:username:password
# then "chmod 0600 /root/.pgpass"
#
# Coloque este arquivo em /opt/bin/alfresco-bkp.sh
# Adicione este script ao cron com: 30 01 * * * /opt/bin/alfresco-bkp.sh

ALF_HOME="/opt/alfresco-community"
LOCAL_BKP="/opt/bkp/alfresco"
REMOTE_BKP="/cygdrive/z/bkpAlfresco"
DB_HOME="/opt/alfresco-community/postgresql"
DB_BKP="$LOCAL_BKP/alfresco-db.sql"
LOGFILE="$LOCAL_BKP/alfresco-bkp.log"

#Local & Remote Repository (Remote needs to be mounted)
ACTIVE_RP="/opt/alfresco-community/alf_data"
BKP_RP="/cygdrive/z/bkpAlfresco/alfresco-community/alf_data"

#Local & Remote LetsEncrypt Certificates
CERTS_LOCAL="/etc/letsencrypt/live/alfresco.cpn.com.br/"
CERTS_REMOTE="/cygdrive/d/TI/letsencrypt/certs/live/alfresco.cpn.com.br"

nowstamp() {
  echo $(date "+%a %x %R %Z") by $USER
}
clear
printf "Iniciando o backup do Alfresco. Pode demorar, tenha paciência..."
printf "\n\n-------------------------------------------------------" >> $LOGFILE
printf "\nBackup started at $(nowstamp)" >> $LOGFILE

#Stopping Alfresco
printf "\nParando o Alfresco..."
service alfresco stop >> $LOGFILE
printf "ok"

#Sttarting PostreSQL of Alfresco Database
printf "\nReiniciando a base de dados..."
$DB_HOME/scripts/ctl.sh start $LOGFILE
printf "ok"

#Sync the local to the remote repository files
printf "\nSincronizando o repositório..."
printf "\n\nRelatório do diretório .../contentstore/" >> $LOGFILE
rsync -a --delete --stats -h $ACTIVE_RP/contentstore/ sienge:$BKP_RP/contentstore/ >> $LOGFILE

printf "\n\nRelatório do diretório .../solr4/" >> $LOGFILE
rsync -a --delete --stats -h $ACTIVE_RP/solr4/ sienge:$BKP_RP/solr4/ >> $LOGFILE
printf "ok"

#Database Backup, in text format (.sql)
printf "\nGerando backup da base de dados ativa..."
$DB_HOME/bin/pg_dump -h localhost -p 5432 -Ualfresco alfresco > $DB_BKP 
printf "ok"
printf "\n\nRelatório do arquivo $DB_BKP \n" >> $LOGFILE
stat $DB_BKP >> $LOGFILE 

#Edited Settings Files
cp $ALF_HOME/tomcat/shared/classes/alfresco-global.properties $LOCAL_BKP
cp $ALF_HOME/tomcat/conf/server.xml $LOCAL_BKP
cp $ALF_HOME/tomcat/shared/classes/alfresco/web-extension/share-config-custom.xml $LOCAL_BKP
cp $ALF_HOME/solr4/archive-SpacesStore/conf/solrcore.properties $LOCAL_BKP/archive
cp $ALF_HOME/solr4/workspace-SpacesStore/conf/solrcore.properties $LOCAL_BKP/workspace
cp /opt/bin/alfresco-bkp.sh $LOCAL_BKP
cp /etc/init.d/alfresco $LOCAL_BKP
mv $LOCAL_BKP/alfresco $LOCAL_BKP/alfresco.service
#incluir tb arquivo do cron

# Restart Alfresco

printf "\nReiniciando o alfresco..."
service alfresco start >> $LOGFILE
printf "ok"

printf "\nBackup finished at $(nowstamp)" >> $LOGFILE
printf "\n-------------------------------------------------------\n" >> $LOGFILE

printf "\nCopiando arquivos de configuração ao local remoto..."
rsync -av -h $LOCAL_BKP/* sienge:$REMOTE_BKP
printf "ok"

#printf "\nReplicando a base de dados remota..."
# Para configurar a base de dados remota para receber conexões de rede
## abre o arquivo [alfresco-community]/alf_data/postgresql/pg_hba.conf
## e adicione a linha abaixo nos host IPv4
##     host   all  all 192.168.0.98/32   md5
## sendo que o ip é o da máquina que fará a requisição
## Edite também o arquivo [alfresco-community]/alf_data/postgresql/postgresql.conf
## e descomente a linha: postgresql.conf
## Por último, no computador que fará a consulta, edite ou crie um arquivo
## em /root/.pgpass, e adicione a autenticação usada para se conectar, no formato
## hostip:port:patabasename:username:password

## Uncomment next line to replicate remote database
#$DB_HOME/bin/dropdb -h 192.168.0.99 -p 5432 -U alfresco alfresco
#$DB_HOME/bin/createdb -h 192.168.0.99 -p 5432 -U postgres -O alfresco alfresco
#$DB_HOME/bin/psql -q -h 192.168.0.99 -p 5432 -U alfresco alfresco < $DB_BKP
#printf "ok"

printf "\nCopiando certificados letsencrypt para o servidor proxy..."
# (Windows Server \ Apache Web SErver)
# Uma vez que no nosso ambiente o servidor proxy está configurado
# fora do servidor linux, é necessário copiar os certificados para lá. 
# Estes certificados já são atualizados automaticamente a cada 60 dias,
# conforme configuração automática do letsencrypt durante sua instalação.
rsync -avL -h $CERTS_LOCAL sienge:$CERTS_REMOTE
printf "ok"

printf "\nFim do script. Veja o resultado no log $LOGFILE \n"
