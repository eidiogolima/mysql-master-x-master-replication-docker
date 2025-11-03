#!/bin/bash

echo "🔍 Verificando Permissões do Usuário Replicador"
echo "==============================================="

if [ -z "$1" ] || [ -z "$2" ]; then
    echo "❌ Uso: ./check-replication-permissions.sh <IP_SERVER1> <IP_SERVER2>"
    echo ""
    echo "Exemplo: ./check-replication-permissions.sh  00.00.000.000 00.00.000.000"
    exit 1
fi

SERVER1_IP="$1"
SERVER2_IP="$2"

check_permissions() {
    local server_ip=$1
    local server_name=$2
    
    echo "🖥️  Verificando $server_name ($server_ip):"
    echo "=========================================="
    
    # Verificar se usuário existe
    USER_EXISTS=$(mysql -h$server_ip -uroot -pteste123 -e "SELECT User FROM mysql.user WHERE User='replicador';" 2>/dev/null | grep replicador)
    
    if [ -n "$USER_EXISTS" ]; then
        echo "✅ Usuário 'replicador' existe"
        
        # Verificar permissões específicas
        echo "📋 Permissões do usuário 'replicador':"
        mysql -h$server_ip -uroot -pteste123 -e "
            SELECT 
                Repl_slave_priv as 'REPLICATION SLAVE',
                Repl_client_priv as 'REPLICATION CLIENT',
                Select_priv as 'SELECT'
            FROM mysql.user 
            WHERE User='replicador' AND Host='%';
        " 2>/dev/null
        
        # Testar conexão como replicador
        if mysql -h$server_ip -ureplicador -pteste123 -e "SELECT 'Conexão OK' as status;" > /dev/null 2>&1; then
            echo "✅ Conexão como replicador: OK"
        else
            echo "❌ Conexão como replicador: FALHOU"
        fi
        
        # Testar SHOW MASTER STATUS
        if mysql -h$server_ip -ureplicador -pteste123 -e "SHOW MASTER STATUS;" > /dev/null 2>&1; then
            echo "✅ SHOW MASTER STATUS: OK"
        else
            echo "❌ SHOW MASTER STATUS: FALHOU (falta REPLICATION CLIENT)"
        fi
        
    else
        echo "❌ Usuário 'replicador' NÃO existe"
    fi
    
    echo ""
}

# Verificar ambos os servidores
check_permissions "$SERVER1_IP" "Server 1"
check_permissions "$SERVER2_IP" "Server 2"

echo "💡 Permissões Necessárias para Replicação:"
echo "==========================================="
echo "✅ REPLICATION SLAVE  - Básica para replicação"
echo "✅ REPLICATION CLIENT - Essencial para SHOW MASTER STATUS"
echo "✅ SELECT             - Necessária para algumas operações"
echo ""
echo "📝 Comando para corrigir (se necessário):"
echo "   DROP USER IF EXISTS 'replicador'@'%';"
echo "   CREATE USER 'replicador'@'%' IDENTIFIED WITH mysql_native_password BY 'teste123';"
echo "   GRANT REPLICATION SLAVE ON *.* TO 'replicador'@'%';"
echo "   GRANT SELECT ON *.* TO 'replicador'@'%';"
echo "   GRANT REPLICATION CLIENT ON *.* TO 'replicador'@'%';"
echo "   FLUSH PRIVILEGES;"