#!/bin/bash

# --- CONFIGURAÇÕES ---
# Usa a variável de ambiente se existir, senão usa um e-mail padrão
ALERT_EMAIL=${ALERT_EMAIL:-seu-email-pessoal@exemplo.com}

# Caminho para o arquivo de log (dentro da pasta do projeto montada em /app)
LOG_FILE="/app/logs/check_health.log"

# Caminho para um arquivo de estado, para não enviar e-mails a cada 5 minutos
STATUS_FILE="/tmp/docker_unhealthy_alert_sent"


# --- LÓGICA DO SCRIPT ---

# Mensagem inicial, gravada no log e no stdout
echo "Verificando a saúde dos containers em $(date)..." | tee -a $LOG_FILE

# Procura por containers com o status 'unhealthy'
UNHEALTHY_CONTAINERS=$(docker ps --format '{{.Names}}\t{{.Status}}' | grep 'unhealthy')

# Se a variável NÃO estiver vazia, significa que encontrámos containers com problemas
if [ -n "$UNHEALTHY_CONTAINERS" ]; then
  # Verifica se já enviámos um alerta recentemente
  if [ ! -f "$STATUS_FILE" ]; then
    # Se não enviámos, regista o problema e envia o e-mail
    echo "ALERTA: Container(s) 'unhealthy' detetado(s):" | tee -a $LOG_FILE
    echo "$UNHEALTHY_CONTAINERS" | tee -a $LOG_FILE
    
    BODY="Container(s) 'unhealthy' detetado(s) no servidor LUNA/ALFRESCO: $UNHEALTHY_CONTAINERS"

    printf "Subject: [ALERTA] Container Docker 'Unhealthy' no Servidor LUNA/ALFRESCO\n\n%s" "$BODY" | msmtp -t $ALERT_EMAIL
    
    echo "E-mail de alerta enviado." | tee -a $LOG_FILE
    # Cria o arquivo de estado para evitar o envio de mais e-mails
    touch "$STATUS_FILE"
  else
    # Se o arquivo de estado já existe, apenas registra que o problema persiste
    echo "INFO: O estado 'unhealthy' persiste. Alerta já foi enviado." | tee -a $LOG_FILE
  fi
else
  # Se não há containers com problemas...
  # Verifica se o arquivo de estado existe (o que significa que o problema foi resolvido)
  if [ -f "$STATUS_FILE" ]; then
    # Se existia, regista a recuperação e apaga o arquivo para rearmar o alerta
    echo "RECUPERAÇÃO: Todos os containers estão saudáveis. A rearmar o sistema de alerta." | tee -a $LOG_FILE
    rm "$STATUS_FILE"
  else
    # Se tudo já estava bem, apenas regista a verificação bem-sucedida
    echo "SUCESSO: Todos os containers estão saudáveis." | tee -a $LOG_FILE
  fi
fi