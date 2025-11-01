#!/bin/bash

# Script para verificar status da replicação Master x Master

echo "🔍 Verificando Status da Replicação Master x Master"
echo "=================================================="

# Verificar se os containers estão rodando
echo "📦 Status dos Containers:"
docker ps --filter "name=mysql-master" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Verificar replicação no Master 1
echo "🖥️  MASTER 1 (mysql-master-1) - Status da Replicação:"
echo "---------------------------------------------------"
MASTER1_STATUS=$(docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null)

if [ -z "$MASTER1_STATUS" ]; then
    echo "❌ Replicação não configurada no Master 1"
else
    echo "Slave_IO_Running: $(echo "$MASTER1_STATUS" | grep "Slave_IO_Running:" | awk '{print $2}')"
    echo "Slave_SQL_Running: $(echo "$MASTER1_STATUS" | grep "Slave_SQL_Running:" | awk '{print $2}')"
    echo "Seconds_Behind_Master: $(echo "$MASTER1_STATUS" | grep "Seconds_Behind_Master:" | awk '{print $2}')"
    
    LAST_ERROR=$(echo "$MASTER1_STATUS" | grep "Last_Error:" | cut -d' ' -f2-)
    if [ "$LAST_ERROR" != "Last_Error:" ]; then
        echo "Last_Error: $LAST_ERROR"
    else
        echo "Last_Error: Nenhum erro"
    fi
fi

echo ""

# Verificar replicação no Master 2
echo "🖥️  MASTER 2 (mysql-master-2) - Status da Replicação:"
echo "---------------------------------------------------"
MASTER2_STATUS=$(docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null)

if [ -z "$MASTER2_STATUS" ]; then
    echo "❌ Replicação não configurada no Master 2"
else
    echo "Slave_IO_Running: $(echo "$MASTER2_STATUS" | grep "Slave_IO_Running:" | awk '{print $2}')"
    echo "Slave_SQL_Running: $(echo "$MASTER2_STATUS" | grep "Slave_SQL_Running:" | awk '{print $2}')"
    echo "Seconds_Behind_Master: $(echo "$MASTER2_STATUS" | grep "Seconds_Behind_Master:" | awk '{print $2}')"
    
    LAST_ERROR=$(echo "$MASTER2_STATUS" | grep "Last_Error:" | cut -d' ' -f2-)
    if [ "$LAST_ERROR" != "Last_Error:" ]; then
        echo "Last_Error: $LAST_ERROR"
    else
        echo "Last_Error: Nenhum erro"
    fi
fi

echo ""

# Verificar GTID status
echo "🔗 Status GTID:"
echo "---------------"
echo "Master 1 GTID Executed:"
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW GLOBAL VARIABLES LIKE 'gtid_executed';" 2>/dev/null | tail -n +2

echo "Master 2 GTID Executed:"
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW GLOBAL VARIABLES LIKE 'gtid_executed';" 2>/dev/null | tail -n +2

echo ""
echo "✅ Verificação concluída!"
echo "🌐 phpMyAdmin: http://localhost:8085"