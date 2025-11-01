# Dockerfile para executar setup-replication após containers
FROM bash:latest

# Instalar mysql-client para executar comandos MySQL
RUN apk add --no-cache mysql-client

# Copiar o script de setup
COPY ./exec/setup-replication.sh /setup-replication.sh

# Dar permissão de execução
RUN chmod +x /setup-replication.sh

# Variável de ambiente para o IP do Master 1
ENV MASTER1_IP=${MASTER1_IP:-mysql-master-1}

# Executar o script
ENTRYPOINT ["/setup-replication.sh"]
CMD ["${MASTER1_IP}"]
