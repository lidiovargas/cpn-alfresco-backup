# Prepare o projeto

Crie uma rede docker, caso ainda não existe:

```bash
docker network create alfresco_net
```

No host, garanta que o entrypoint.sh tenha permissões de execução

```bash
sudo chmod +x entrypoint.sh
```

Faça um build

```bash
docker compose build
```

# Credenciais

Crie os arquivos de senha em "lote", com os comandos abaixo

```bash
mkdir secrets
# Evite que os comandos fiquem no histórico do shell, desabilitando o histórico
set +o history
echo -n 'sua_senha' > ./secrets/db_password.txt
echo -n 'sua_senha' > ./secrets/restic_password.txt
echo -n 'sua_senha' > ./secrets/aws_access_key_id.txt
echo -n 'sua_senha' > ./secrets/aws_secret_access_key.txt
# Reabilite o histórico do shell
set -o history

# Opcional, mas recomendado:
# Torne a pasta secrets acessível apenas para o root, por segurança:
sudo chown -R root:root ./secrets/
# Define as permissões para que APENAS o dono (root) possa ler os ficheiros
# Ninguém mais, nem mesmo outros utilizadores no mesmo grupo, pode ver o conteúdo.
## obs: alguns serviços não são executados como root (p.e. www-data), assim 0600 tornaria os secrets inacessíveis
sudo chmod 644 ./secrets/*.txt
```

# Rotinas de backup

Como rodar o backup manualmente, escolha uma das opções abaixo, conforme sua preferência

```bash
# na velocidade padrão de 10MB/s (80Mbps), e sem parar o Alfresco
docker compose run --rm backup sh ./backup.inc.aws.sh

# parando o serviço do alfresco (para garantir consistência entre DB e repositório alfresco)
docker compose run --rm backup sh ./backup.inc.aws.sh --stop-services

# em velocidade customizada, por exemplo: Download 37.5MB/s (300Mbps) | Upload 18.75MB/s (150Mbps)
docker compose run --rm backup sh ./backup.inc.aws.sh --limit-download=38400 --limit-upload=19200

# em velocidade máxima permitida (usa toda a banda disponível)
docker compose run --rm backup sh ./backup.inc.aws.sh --limit-download=0 --limit-upload=0

# parando o serviço do alfresco, e com controle de velocidade (sugestão para CRON)
docker compose run --rm backup sh ./backup.inc.aws.sh --stop-services --limit-download=38400 --limit-upload=19200
```

Como ver snapshots

```bash
docker compose run --rm backup restic snapshots
```

Como restaurar um snapshot:

```bash
# Cria uma pasta de restauro
mkdir ./restore_temp
# Restaura o último backup para essa pasta
docker compose run --rm -v "$(pwd)/restore_temp":/restore backup restic restore SNAPSHOT_ID --target /restore
# Por exemplo
docker compose run --rm -v "$(pwd)/restore_temp":/restore backup restic restore e4411202 --target /restore
```

Como excluir um snapshot:

```bash
docker compose run --rm backup restic forget --prune SNAPSHOT_ID
```

Se precisar montar uma unidade de snapshot, para verificar o que tem nela (só funciona no Linux):

```bash
# adicione seu usuário ao grupo `fuse`, para evitar erros de permissão em hosts com AppArmor
sudo usermod -aG fuse $USER
# (Num terminal) Crie uma pasta temporária e monte o repositório.
# Este comando ficará em execução, mantendo a montagem ativa.
mkdir -p ./mount_temp
# Rode a montagem
docker compose run --build --rm --name restic_mount_process -v "$(pwd)/mount_temp":/mnt/restic backup-mount restic mount /mnt/restic

> NOTA: A montagem acontece DENTRO do container e não é visível diretamente na pasta local.
> Use `docker exec` para interagir com os arquivos montados.

# (Num SEGUNDO terminal) Navegue pelo conteúdo montado usando `docker exec`.
# Para ver o conteúdo do snapshot mais recente:
docker exec -it restic_mount_process ls -l /mnt/restic/snapshots/latest/

# Para ver o conteúdo de um snapshot específico pelo seu ID:
docker exec -it restic_mount_process ls -l /mnt/restic/ids/SNAPSHOT_ID/

# Para desmontar, volte ao primeiro terminal e pressione Ctrl+C. O container será
# automaticamente removido.
```

> NOTA: faz a montagem de todo o repositório, e não só de um snapshot.
> Custaria muito caro (tempo) aplicar essa montagem, já que meu repositório está na AWS S3 e tem 2.5T aberto (ou 1T armazenado), com aproximadadmente 6000 snapshots?
> A resposta curta é: não, não custará caro em tempo para iniciar a montagem, mesmo com um repositório tão grande.
> A "mágica" do restic mount é que ele funciona como um sistema de arquivos virtual sob demanda.

# Como controlar outros Containers de dentro de um container?

Ao fazer o backup da base de dados com ferramentas com `pg_dump`, a ferramenta do postgres
cria um snapshot transacionalmente consistente do banco de dados no momento em que é iniciado.
Você pode executá-lo com o banco de dados online e recebendo escritas sem se preocupar
com dados corrompidos ou inconsistentes no seu backup.

Entretanto, se fizer backup do repositório do alfresco com ele ligado, mesmo que a BD esteja
consistente, o repositório pode ficar defasado da BD. Quando rodávamos o backup dentro
de um mesmo host linux, havia a flexibilidade de parar e começar serviços à vontade, ao
custo de maior confusão para restauro em caso de desastres, e de portar o projeto para
outra infraestrutura.

Ao portar para Docker, há o desafio de fazer esse desligamento e religamento dos serviços.

Você não pode (e não deve) instalar o cliente Docker dentro do seu container
de backup para controlar outros containers. Isso é um anti-padrão.

A solução elegante e segura que o Docker oferece para este cenário é
**montar o socket do Docker do host dentro do container de backup.**

O arquivo de socket `/var/run/docker.sock` é a API que o comando docker
da sua máquina usa para se comunicar com o daemon do Docker. Ao dar
acesso a esse socket a um container, você efetivamente dá a ele permissão
para enviar comandos ao daemon do Docker do host, como docker stop e docker start.

> Nota de Segurança: Dar acesso ao docker.sock é equivalente a dar
> permissões de root no host. Como este é um container de administração
> controlado por você para uma tarefa específica, o risco o é gerenciável.
> Nunca faça isso em containers expostos à internet (como um servidor web).
