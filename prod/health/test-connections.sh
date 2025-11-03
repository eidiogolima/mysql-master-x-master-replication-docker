#!/bin/bash

echo "🔍 Diagnóstico Completo da Replicação"
echo "===================================="

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "❌ Uso: ./test-connections.sh <IP_SERVER1> <IP_SERVER2>"
    echo ""
    echo "Exemplo: ./test-connections.sh  00.00.000.000 00.00.000.000"
    exit 1
fi

# IPs dos servidores
SERVER1_IP="$1"
SERVER2_IP="$2"

echo "📡 Server 1: $SERVER1_IP"
echo "📡 Server 2: $SERVER2_IP"
echo ""

diagnose_server() {
    local server_ip=$1
    local server_name=$2
    
    echo "🔍 Diagnosticando $server_name ($server_ip):"
    echo "============================================"
    
    # 1. Verificar usuário replicador
    echo "1️⃣  Verificando usuário replicador..."
    if mysql -h$server_ip -ureplicador -pteste123 -e "SELECT 'OK' as status;" 2>/dev/null; then
        echo "   ✅ Usuário replicador funciona"
    else
        echo "   ❌ Usuário replicador NÃO funciona"
        echo "   📋 Usuários existentes:"
        mysql -h$server_ip -uroot -pteste123 -e "SELECT User, Host FROM mysql.user WHERE User LIKE '%replic%';" 2>/dev/null
    fi
    
    # 2. Verificar GTID
    echo ""
    echo "2️⃣  Verificando GTID..."
    GTID_MODE=$(mysql -h$server_ip -uroot -pteste123 -e "SHOW VARIABLES LIKE 'gtid_mode';" 2>/dev/null | grep gtid_mode | awk '{print $2}')
    GTID_CONSISTENCY=$(mysql -h$server_ip -uroot -pteste123 -e "SHOW VARIABLES LIKE 'enforce_gtid_consistency';" 2>/dev/null | grep enforce_gtid_consistency | awk '{print $2}')
    
    echo "   GTID Mode: ${GTID_MODE:-'OFF'}"
    echo "   GTID Consistency: ${GTID_CONSISTENCY:-'OFF'}"
    
    if [ "$GTID_MODE" = "ON" ] && [ "$GTID_CONSISTENCY" = "ON" ]; then
        echo "   ✅ GTID configurado corretamente"
    else
        echo "   ❌ GTID não está habilitado"
    fi
    
    # 3. Verificar bind-address
    echo ""
    echo "3️⃣  Verificando bind-address..."
    BIND_ADDRESS=$(mysql -h$server_ip -uroot -pteste123 -e "SHOW VARIABLES LIKE 'bind_address';" 2>/dev/null | grep bind_address | awk '{print $2}')
    echo "   Bind Address: $BIND_ADDRESS"
    
    if [ "$BIND_ADDRESS" = "0.0.0.0" ] || [ "$BIND_ADDRESS" = "*" ]; then
        echo "   ✅ Bind address permite conexões externas"
    else
        echo "   ⚠️  Bind address pode estar restritivo"
    fi
    
    # 4. Status de replicação
    echo ""
    echo "4️⃣  Status de replicação atual..."
    SLAVE_STATUS=$(mysql -h$server_ip -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null)
    
    if [ -n "$SLAVE_STATUS" ]; then
        echo "   📊 Replicação configurada:"
        echo "$SLAVE_STATUS" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Master_Host|Last_Error)" | head -10
    else
        echo "   ℹ️  Nenhuma replicação configurada"
    fi
    
    echo ""
    echo "----------------------------------------"
    echo ""
}

# Diagnosticar ambos os servidores
diagnose_server "$SERVER1_IP" "Server 1"
diagnose_server "$SERVER2_IP" "Server 2"

echo "💡 Soluções Recomendadas:"
echo "========================"
echo "1. Se usuário replicador não funciona: execute fix-replication-user.sh"
echo "2. Se GTID está OFF: execute enable-gtid.sh"
echo "3. Para reconfigurar tudo: execute reset-replication.sh"