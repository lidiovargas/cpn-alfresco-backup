# Passo 1: Usamos a imagem oficial do restic, que é baseada em Alpine Linux
FROM restic/restic:latest

# Passo 2: Adicionamos as ferramentas cliente necessárias
RUN apk --no-cache add postgresql-client docker-cli

# Passo 3: Definimos o nosso diretório de trabalho dentro do container
WORKDIR /app

# Passo 4: Copiamos os nossos scripts para dentro da imagem, no diretório /app
# A origem '.' é a pasta 'backup/' no seu PC (o contexto do build)
# O destino '.' é o WORKDIR atual (/app) dentro da imagem/container
COPY entrypoint.sh .
COPY backup.inc.aws.sh .
COPY functions.sh .

# Passo 5: Garantimos que os scripts têm permissões de execução dentro da imagem
RUN chmod +x ./entrypoint.sh ./backup.inc.aws.sh

# Passo 6: Definimos o nosso script como o PONTO DE ENTRADA do container
ENTRYPOINT ["./entrypoint.sh"]