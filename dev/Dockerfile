# Dockerfile para executar setup-replication após containers (DEV)
FROM bash:latest

# Instalar mysql-client para executar comandos MySQL
RUN apk add --no-cache mysql-client

# Copiar o script de setup
COPY ./setup-replication.sh /setup-replication.sh

# Dar permissão de execução
RUN chmod +x /setup-replication.sh

# Variável de ambiente para o IP do Master 2
ENV MASTER2_IP=${MASTER2_IP:-mysql-master-2}

# Executar o script
ENTRYPOINT ["/setup-replication.sh"]
CMD ["${MASTER2_IP}"]
