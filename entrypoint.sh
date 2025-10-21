#!/bin/sh

# Ativa o "exit on error"
set -e

# Exporta as credenciais da AWS a partir dos ficheiros de secrets do Docker.
# Esta lógica agora vive aqui, e será executada sempre que o container iniciar.
export AWS_ACCESS_KEY_ID=$(cat "$AWS_ACCESS_KEY_ID_FILE")
export AWS_SECRET_ACCESS_KEY=$(cat "$AWS_SECRET_ACCESS_KEY_FILE")
export ALFRESCO_DB_PASSWORD=$(cat "$ALFRESCO_DB_PASSWORD_FILE")

# A linha mais importante:
# 'exec "$@"' diz ao shell para "substituir este script pelo comando
# que foi passado como argumento para o container".
# Se você rodar '... backup restic snapshots', "$@" será 'restic snapshots'.
# Se você rodar '... backup sh /backup.sh', "$@" será 'sh /backup.sh'.
exec "$@"