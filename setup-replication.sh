#!/bin/bash

# Script para configurar replicação Master x Master automaticamente
# Execute este script após os containers estarem rodando

echo "🚀 Configurando Replicação Master x Master..."

# Aguardar containers ficarem prontos
echo "⏳ Aguardando containers ficarem prontos..."
sleep 30

# Criar usuário de replicação no Master 1
echo "👤 Criando usuário de replicação no Master 1..."
docker exec mysql-master-1 mysql -uroot -pteste123 -e "
CREATE USER IF NOT EXISTS 'replicador'@'%' IDENTIFIED WITH mysql_native_password BY 'teste123';
GRANT REPLICATION SLAVE ON *.* TO 'replicador'@'%';
FLUSH PRIVILEGES;
"

# Criar usuário de replicação no Master 2
echo "👤 Criando usuário de replicação no Master 2..."
docker exec mysql-master-2 mysql -uroot -pteste123 -e "
CREATE USER IF NOT EXISTS 'replicador'@'%' IDENTIFIED WITH mysql_native_password BY 'teste123';
GRANT REPLICATION SLAVE ON *.* TO 'replicador'@'%';
FLUSH PRIVILEGES;
"

# Aguardar um momento
sleep 5

# Configurar Master 1 para replicar do Master 2 usando GTID
echo "🔄 Configurando Master 1 para replicar do Master 2 (GTID)..."
docker exec mysql-master-1 mysql -uroot -pteste123 -e "
STOP SLAVE;
RESET SLAVE ALL;
CHANGE MASTER TO
    MASTER_HOST='mysql-master-2',
    MASTER_USER='replicador',
    MASTER_PASSWORD='teste123',
    MASTER_AUTO_POSITION=1;
START SLAVE;
"

# Configurar Master 2 para replicar do Master 1 usando GTID
echo "🔄 Configurando Master 2 para replicar do Master 1 (GTID)..."
docker exec mysql-master-2 mysql -uroot -pteste123 -e "
STOP SLAVE;
RESET SLAVE ALL;
CHANGE MASTER TO
    MASTER_HOST='mysql-master-1',
    MASTER_USER='replicador',
    MASTER_PASSWORD='teste123',
    MASTER_AUTO_POSITION=1;
START SLAVE;
"

# Aguardar conexão estabelecer
sleep 10

# Verificar status da replicação
echo "✅ Verificando status da replicação..."
echo ""
echo "=== STATUS REPLICAÇÃO MASTER 1 ==="
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Last_Error|Seconds_Behind_Master)"

echo ""
echo "=== STATUS REPLICAÇÃO MASTER 2 ==="
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Last_Error|Seconds_Behind_Master)"

echo ""
echo "✅ Configuração de replicação Master x Master concluída!"
echo "🌐 Acesse o phpMyAdmin em: http://localhost:8085"
echo "🔧 Para monitorar: execute './check-replication.sh'"