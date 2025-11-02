# Dockerfile para executar setup-replication após containers
# O script será executado DENTRO do container MySQL
FROM bash:latest

# Copiar o script de setup
COPY ./exec/setup-replication.sh /setup-replication.sh

# Dar permissão de execução
RUN chmod +x /setup-replication.sh

# Variável de ambiente para o IP do Master 1
ENV MASTER1_IP=${MASTER1_IP:-mysql-master-1}

# Executar o script
ENTRYPOINT ["/setup-replication.sh"]
CMD ["${MASTER1_IP}"]
