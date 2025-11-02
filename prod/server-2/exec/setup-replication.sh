#!/bin/bash

# Script para configurar replicação no Master 2
# Execute APÓS o setup-replication.sh no Master 1

if [ -z "$1" ]; then
    echo "❌ Erro: IP do Master 1 não foi fornecido!"
    echo ""
    echo "📝 Uso: ./setup-replication.sh <IP_MASTER_1>"
    echo ""
    echo "Exemplo:"
    echo "  ./setup-replication.sh 192.168.1.10"
    echo ""
    exit 1
fi

MASTER1_IP="$1"

echo "🚀 Configurando Replicação no Master 2..."
echo "📡 Master 1: $MASTER1_IP"
echo "📡 Master 2: localhost"
echo ""

# Aguardar containers ficarem prontos
echo "⏳ Aguardando Master 2 ficar pronto..."
sleep 10

# Criar usuário de replicação no Master 2
echo "👤 Criando usuário de replicação no Master 2..."
mysql -uroot -pteste123 -e "
CREATE USER IF NOT EXISTS 'replicador'@'%' IDENTIFIED WITH mysql_native_password BY 'teste123';
GRANT REPLICATION SLAVE ON *.* TO 'replicador'@'%';
FLUSH PRIVILEGES;
"

if [ $? -ne 0 ]; then
    echo "❌ Erro ao criar usuário no Master 2"
    exit 1
fi

echo "✅ Usuário criado no Master 2"
sleep 5

# Configurar Master 2 para replicar do Master 1
echo "🔄 Configurando Master 2 para replicar do Master 1 (GTID)..."
mysql -uroot -pteste123 -e "
STOP SLAVE;
RESET SLAVE ALL;
CHANGE MASTER TO
    MASTER_HOST='$MASTER1_IP',
    MASTER_USER='replicador',
    MASTER_PASSWORD='teste123',
    MASTER_AUTO_POSITION=1;
START SLAVE;
"

if [ $? -ne 0 ]; then
    echo "❌ Erro ao configurar replicação no Master 2"
    exit 1
fi

echo "✅ Master 2 configurado para replicar"

# Aguardar conexão estabelecer
sleep 10

# Verificar status da replicação
echo ""
echo "✅ Verificando status da replicação..."
echo ""
echo "=== STATUS REPLICAÇÃO MASTER 2 ==="
mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Last_Error|Seconds_Behind_Master|Master_Host)"

echo ""

# Verificar se há erros
SLAVE_IO=$(mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep "Slave_IO_Running:" | awk '{print $2}')
SLAVE_SQL=$(mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep "Slave_SQL_Running:" | awk '{print $2}')

if [ "$SLAVE_IO" = "Yes" ] && [ "$SLAVE_SQL" = "Yes" ]; then
    echo "🎉 Replicação ATIVA no Master 2!"
    echo ""
    echo "✅ REPLICAÇÃO BIDIRECIONAL FUNCIONANDO!"
else
    echo "⚠️  Verificando status..."
    if [ "$SLAVE_IO" = "Connecting" ]; then
        echo "🔄 Master 2 ainda está tentando conectar ao Master 1..."
        echo "💡 Dica: Verifique se o IP '$MASTER1_IP' está correto e acessível"
    fi
fi

echo ""
echo "✅ Configuração de replicação Master 2 concluída!"
echo ""
echo "🌐 Próximos passos:"
echo "   1. Acesse o phpMyAdmin em: http://localhost:8085"
echo "   2. Para monitorar: execute './check-replication.sh'"