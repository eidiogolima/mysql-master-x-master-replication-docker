#!/bin/bash

# Script para configurar replicação Master x Master automaticamente
# VERSÃO: Para executar DENTRO do container MySQL
# Uso: docker exec mysql-master-1 bash /scripts/setup-replication.sh <IP_MASTER_2>

set -e

# Verificar se IP foi fornecido
if [ -z "$1" ]; then
    echo "❌ Erro: IP do Master 2 não foi fornecido!"
    echo ""
    echo "📝 Uso: bash /scripts/setup-replication.sh <IP_MASTER_2>"
    echo ""
    echo "Exemplos:"
    echo "  bash /scripts/setup-replication.sh 192.168.1.20"
    echo "  bash /scripts/setup-replication.sh 172.20.0.3"
    echo "  bash /scripts/setup-replication.sh mysql-master-2  (rede Docker)"
    echo ""
    exit 1
fi

MASTER2_IP="$1"
MASTER1_IP="localhost"  # Dentro do container, sempre é localhost

echo "🚀 Configurando Replicação Master x Master..."
echo "📡 Master 1: $MASTER1_IP (dentro do container)"
echo "📡 Master 2: $MASTER2_IP"
echo ""

# Aguardar MySQL estar pronto
echo "⏳ Aguardando MySQL ficar pronto..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
    if mysql -h"$MASTER1_IP" -uroot -pteste123 -e "SELECT 1" 2>/dev/null; then
        echo "✅ MySQL está pronto"
        break
    fi
    attempt=$((attempt + 1))
    echo "Tentativa $attempt/$max_attempts..."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    echo "❌ Erro: MySQL não respondeu após 60 segundos"
    exit 1
fi

# Criar usuário de replicação no Master 1
echo "👤 Criando usuário de replicação no Master 1..."
mysql -h"$MASTER1_IP" -uroot -pteste123 -e "
CREATE USER IF NOT EXISTS 'replicador'@'%' IDENTIFIED WITH mysql_native_password BY 'teste123';
GRANT REPLICATION SLAVE ON *.* TO 'replicador'@'%';
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
mysql -h"$MASTER1_IP" -uroot -pteste123 -e "
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
mysql -h"$MASTER1_IP" -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Last_Error|Seconds_Behind_Master|Master_Host)" || echo "Aguardando status..."

echo ""

# Verificar se há erros
SLAVE_IO=$(mysql -h"$MASTER1_IP" -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running:" | awk '{print $2}' || echo "No")
SLAVE_SQL=$(mysql -h"$MASTER1_IP" -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_SQL_Running:" | awk '{print $2}' || echo "No")

if [ "$SLAVE_IO" = "Yes" ] && [ "$SLAVE_SQL" = "Yes" ]; then
    echo "🎉 Replicação ATIVA no Master 1!"
    exit 0
else
    echo "⚠️  Verificando status..."
    if [ "$SLAVE_IO" = "Connecting" ]; then
        echo "🔄 Master 1 ainda está tentando conectar ao Master 2..."
        echo "💡 Dica: Verifique se o IP '$MASTER2_IP' está correto e acessível"
        exit 0
    fi
fi

echo ""
echo "✅ Configuração de replicação Master 1 concluída!"