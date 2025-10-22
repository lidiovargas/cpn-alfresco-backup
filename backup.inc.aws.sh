#!/bin/bash

SCRIPT_PREFIX="backup.inc.aws.sh"

# Garante que um pipeline falhe se qualquer comando nele falhar.
set -o pipefail

# Inicializa o código de saída como sucesso
EXIT_CODE=0
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

# Variável para acumular mensagens de erro
ERROR_MESSAGES=""

# STOP ALFRESCO
if [ $STOP == true ]; then
	echo "$(nowstamp) Stopping Alfresco application container..." 2>&1 | tolog
	docker stop alfresco2017_community 2>&1 | tolog
	echo "Awaiting 10s for graceful shutdown..." | tolog
	sleep 10s || { ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao aguardar o desligamento do Alfresco.\n"; EXIT_CODE=1; }
	# Adicionado tratamento de erro para o sleep, embora seja raro falhar
fi


## DATABASE
echo $(nowstamp) Alfresco Database Backup... 2>&1 | tolog
DUMP_FILE="/srv/data/alfresco-db.sql"

# A variável ALFRESCO_DB_PASSWORD é exportada pelo entrypoint.sh
# Deixamos o restic gerenciar a compressão para maximizar a desduplicação.
echo "$(nowstamp) Creating database dump..." 2>&1 | tolog
PGPASSWORD=$ALFRESCO_DB_PASSWORD pg_dump -h $ALFRESCO_DB_HOST -U $ALFRESCO_DB_USER -d $ALFRESCO_DB_NAME --clean > $DUMP_FILE || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao criar o dump do banco de dados.\n"
  EXIT_CODE=1
}

echo "$(nowstamp) Backing up database dump with restic..." 2>&1 | tolog
restic backup $DUMP_FILE \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 2>&1 | tolog || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao fazer backup do dump do banco de dados com restic.\n"
  EXIT_CODE=1
}

echo "$(nowstamp) Removing temporary dump file..." 2>&1 | tolog
rm $DUMP_FILE 2>&1 || { ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao remover o arquivo de dump temporário.\n"; EXIT_CODE=1; }


# # REPOSITORY - CONTENTSTORE
FROM=/srv/data/alfresco-community/alf_data/contentstore/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 2>&1 | tolog || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao fazer backup do contentstore ($FROM) com restic.\n"
  EXIT_CODE=1
}

# REPOSITORY - TRASH (contentstore.deleted)
FROM=/srv/data/alfresco-community/alf_data/contentstore.deleted/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 2>&1 | tolog || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao fazer backup do contentstore.deleted ($FROM) com restic.\n"
  EXIT_CODE=1
}

# REPOSITORY KEYSTORE
FROM=/srv/data/alfresco-community/alf_data/keystore/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 2>&1 | tolog || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao fazer backup do keystore ($FROM) com restic.\n"
  EXIT_CODE=1
}

# SEARCH INDEXES
FROM=/srv/data/alfresco-community/alf_data/solr4/
echo $(nowstamp) Backup $FROM 2>&1 | tolog
restic backup $FROM \
	--limit-upload $LIMIT_UPLOAD \
 	--limit-download $LIMIT_DOWNLOAD \
 	--no-scan \
 	--verbose 0 2>&1 | tolog || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao fazer backup dos índices Solr ($FROM) com restic.\n"
  EXIT_CODE=1
}

FROM=/srv/data/alfresco-infra
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--exclude-file="/srv/data/alfresco-infra/backup/.restic-exclude" \
	--verbose 0 2>&1 | tolog || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao fazer backup da infraestrutura Alfresco ($FROM) com restic.\n"
  EXIT_CODE=1
}


# APLICAÇÕES QUE NÃO ENVOLVEM SÓ O ALFRESCO

FROM=/srv/data/http-proxy
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 2>&1 | tolog || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao fazer backup do http-proxy ($FROM) com restic.\n"
  EXIT_CODE=1
}

FROM=/srv/data/backup-all
echo $(nowstamp) Backup $FROM/ 2>&1 | tolog
restic backup ${FROM}/ \
	--limit-upload $LIMIT_UPLOAD \
	--limit-download $LIMIT_DOWNLOAD \
	--no-scan \
	--verbose 0 2>&1 | tolog || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao fazer backup de backup-all ($FROM) com restic.\n"
  EXIT_CODE=1
}

# START ALFRESCO
if [ $STOP == true ]; then
	echo "$(nowstamp) Starting Alfresco application container..." 2>&1 | tolog
	docker start alfresco2017_community 2>&1 | tolog
	echo "Awaiting 10s for Alfresco to start..." | tolog
	sleep 10s || { ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao aguardar o início do Alfresco.\n"; EXIT_CODE=1; }
fi

# KEEP LAST 30
echo $(nowstamp) Aplicando política de retenção... 2>&1 | tolog
restic forget \
	--quiet \
	--keep-tag forever \
	--keep-last 70 \
	--keep-weekly 4 \
  --keep-monthly 12 \
  --keep-yearly 5 \
	--prune > /dev/null 2>&1 || {
  ERROR_MESSAGES="${ERROR_MESSAGES}[ERRO] Falha ao aplicar a política de retenção (restic forget --prune).\n"
  EXIT_CODE=1
}

echo $(nowstamp) End of the script $SCRIPT_PREFIX 2>&1 | tolog

# Verifica se houve erros e imprime-os no log
if [ "$EXIT_CODE" -ne 0 ]; then
  echo -e "$(nowstamp) O script de backup terminou com ERROS:\n$ERROR_MESSAGES" | tolog # Esta mensagem irá para o log e para o stdout/stderr do container 'backup'
fi

# Sai com o código de status acumulado
exit $EXIT_CODE
