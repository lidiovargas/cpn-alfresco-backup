#!/bin/bash

# Garante que um pipeline falhe se qualquer comando nele falhar
# Isto é CRUCIAL para que a nossa deteção de erro com '||' funcione com o 'tee'.
# Por padrão, o código de saída de um "pipeline" (uma série de comandos ligados por |) 
# é o do último comando. Se docker compose falhasse, mas o tee conseguisse escrever 
# no ficheiro, o pipeline seria considerado um sucesso. O pipefail muda este comportamento: 
# se qualquer comando no pipeline falhar, todo o pipeline falha, garantindo que a nossa 
# lógica || { ... } seja acionada corretamente.
set -o pipefail

# E-mail para onde os alertas de falha serão enviados
ALERT_EMAIL=$ALERT_EMAIL

# Define o caminho para o ficheiro de log
LOG_FILE="/app/logs/backup_cron.log"

# --- MUDANÇA: Usamos 'tee -a' para escrever no log E no stdout ---
echo "Iniciando tarefa de backup agendada em $(date)..." | tee -a $LOG_FILE

# Executa o comando de backup, enviando a saída para o 'tee'
# O 'tee -a' anexa ao ficheiro de log E mostra na saída padrão do container.
cd $HOST_PROJECT_PATH && /usr/bin/docker compose run --rm backup sh ./backup.inc.aws.sh --stop-services --limit-download=38400 --limit-upload=19200 2>&1 | tee -a $LOG_FILE || {
  
  # Bloco de código a ser executado em caso de falha
  BODY="O script de backup do site CPN Agropecuária falhou em $(date). Verifique os logs detalhados no servidor em: ${LOG_FILE}"
  
  printf "Subject: [ALERTA] Falha no Backup Alfresco \n\n%s" "$BODY" | msmtp -t $ALERT_EMAIL
  
  # A mensagem de erro também vai para ambos os locais
  echo "ERRO: O backup falhou. E-mail de alerta enviado." | tee -a $LOG_FILE
  exit 1 # Termina o script wrapper com um código de erro também
}

# --- MUDANÇA: A mensagem de sucesso também usa 'tee -a' ---
echo "Tarefa de backup concluída com sucesso em $(date)." | tee -a $LOG_FILE