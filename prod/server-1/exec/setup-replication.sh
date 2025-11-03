#!/bin/bash

# Script para configurar replicação Master x Master automaticamente
# Execute este script após os containers estarem rodando
# Uso: ./setup-replication.sh <IP_MASTER_2>

# Verificar se IP foi fornecido
if [ -z "$1" ]; then
    echo "❌ Erro: IP do Master 2 não foi fornecido!"
    echo ""
    echo "📝 Uso: ./setup-replication.sh <IP_MASTER_2>"
    echo ""
    echo "Exemplos:"
    echo "  ./setup-replication.sh 192.168.1.20"
    echo "  ./setup-replication.sh 172.20.0.3"
    echo "  ./setup-replication.sh mysql-master-2  (rede Docker)"
    echo ""
    exit 1
fi

MASTER2_IP="$1"
MASTER1_IP="${2:-mysql-master-1}"  # Usar localhost como padrão para Docker

echo "🚀 Configurando Replicação Master x Master..."
echo "📡 Master 1: localhost"
echo "📡 Master 2: $MASTER2_IP"
echo ""

# Aguardar containers ficarem prontos
echo "⏳ Aguardando containers ficarem prontos..."
sleep 30

# Criar usuário de replicação no Master 1
echo "👤 Criando usuário de replicação no Master 1..."
mysql -uroot -pteste123 -e "
DROP USER IF EXISTS 'replicador'@'%';
CREATE USER 'replicador'@'%' IDENTIFIED WITH mysql_native_password BY 'teste123';
GRANT REPLICATION SLAVE ON *.* TO 'replicador'@'%';
GRANT SELECT ON *.* TO 'replicador'@'%';
GRANT REPLICATION CLIENT ON *.* TO 'replicador'@'%';
FLUSH PRIVILEGES;
"

if [ $? -ne 0 ]; then
    echo "❌ Erro ao criar usuário no Master 1"
    exit 1
fi

echo "✅ Usuário criado no Master 1"
sleep 5

# Configurar Master 1 para replicar do Master 2 usando GTID
echo "🔄 Configurando Master 1 para replicar do Master 2 (GTID)..."
mysql -uroot -pteste123 -e "
STOP SLAVE;
RESET SLAVE ALL;
CHANGE MASTER TO
    MASTER_HOST='$MASTER2_IP',
    MASTER_USER='replicador',
    MASTER_PASSWORD='teste123',
    MASTER_AUTO_POSITION=1;
START SLAVE;
"

if [ $? -ne 0 ]; then
    echo "❌ Erro ao configurar replicação no Master 1"
    exit 1
fi

echo "✅ Master 1 configurado para replicar"

# Aguardar conexão estabelecer
sleep 10

# Verificar status da replicação
echo ""
echo "✅ Verificando status da replicação..."
echo ""
echo "=== STATUS REPLICAÇÃO MASTER 1 ==="
mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Last_Error|Seconds_Behind_Master|Master_Host)"

echo ""

# Verificar se há erros
SLAVE_IO=$(mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep "Slave_IO_Running:" | awk '{print $2}')
SLAVE_SQL=$(mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep "Slave_SQL_Running:" | awk '{print $2}')

if [ "$SLAVE_IO" = "Yes" ] && [ "$SLAVE_SQL" = "Yes" ]; then
    echo "🎉 Replicação ATIVA no Master 1!"
else
    echo "⚠️  Verificando status..."
    if [ "$SLAVE_IO" = "Connecting" ]; then
        echo "🔄 Master 1 ainda está tentando conectar ao Master 2..."
        echo "💡 Dica: Verifique se o IP '$MASTER2_IP' está correto e acessível"
    fi
fi

echo ""
echo "✅ Configuração de replicação Master 1 concluída!"
echo ""
echo "🌐 Próximos passos:"
echo "   1. No Master 2, execute: ./setup-replication.sh $MASTER1_IP"
echo "   2. Acesse o phpMyAdmin em: http://localhost:8085"
echo "   3. Para monitorar: execute './check-replication.sh'"