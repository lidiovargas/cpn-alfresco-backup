# Começamos com uma base Alpine Linux leve
FROM alpine:3.20

# Instalamos as dependências necessárias, incluindo 'tzdata' para fusos horários
RUN apk --no-cache add docker-cli docker-compose msmtp bash tzdata

# Definimos o fuso horário para São Paulo
ENV TZ="America/Sao_Paulo"


# Criamos as pastas necessárias
## No alpine não há /etc/cron.d (como no debian/ubuntu), mas /etc/crontabs
# Em vez de criar o ficheiro de log, criamos um link simbólico para o stdout.
# O comando docker logs mostra a "saída padrão" (stdout) e a "saída de erro" (stderr) 
# do processo principal do container (o processo com PID 1). No nosso caso, o processo 
# principal é crond -f -l 8.
# O crond é um "daemon", um processo que corre em pano de fundo. Quando chega a hora 
# de executar uma tarefa, ele não a executa em si mesmo. Em vez disso, ele cria um 
# processo filho completamente novo para executar o comando agendado 
# (ex: /scripts/check_docker_health.sh).
# A saída do seu script (echo "SUCESSO...") vai para a saída padrão do processo filho. 
# Essa saída não é automaticamente enviada para a saída do processo pai crond (PID 1). 
# Por isso, o docker logs não a vê
# A forma mais limpa e "Docker-nativa" de resolver isto é dizer ao nosso container: 
#     "tudo o que for escrito no meu ficheiro de log (/var/log/cron.log) deve, na 
#     verdade, ser enviado diretamente para a saída padrão principal do container".
# Fazemos isto com um link simbólico (symlink). Vamos transformar o ficheiro de log 
# num atalho para a saída padrão.
RUN mkdir -p /etc/crontabs /var/log && \
    ln -sf /dev/stdout /var/log/cron.log

# Definimos o diretório de trabalho
WORKDIR /app

# Copiamos os nossos scripts para dentro da imagem
COPY check_docker_health.sh ./check_docker_health.sh
COPY backup_wrapper.sh ./backup_wrapper.sh
# Copiamos o nosso ficheiro crontab.txt para o local correto que o 'crond' do Alpine lê
COPY crontab.txt /etc/crontabs/root

# Copiamos o nosso ficheiro crontab de TESTE para o local correto
#COPY crontab_teste.txt /etc/crontabs/root

# Damos permissão de execução aos scripts e ao crontab
RUN chmod -R +x /app && \
    chmod 0644 /etc/crontabs/root && \
    chmod 0644 /var/log/cron.log

# Definimos o comando para iniciar o serviço cron em primeiro plano quando o container arrancar
CMD ["crond", "-f", "-l", "8"]