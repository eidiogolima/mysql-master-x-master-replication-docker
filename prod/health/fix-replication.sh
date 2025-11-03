#!/bin/bash

echo "🔧 Corrigindo Usuário Replicador e Replicação"
echo "============================================="


if [ -z "$1" ] || [ -z "$2" ]; then
    echo "❌ Uso: ./fix-replication.sh <IP_SERVER1> <IP_SERVER2>"
    echo ""
    echo "Exemplo: ./fix-replication.sh  00.00.000.000 00.00.000.000"
    exit 1
fi

SERVER1_IP="$1"
SERVER2_IP="$2"

echo "🎯 Corrigindo permissões e replicação"
echo ""

# 1. Corrigir usuário replicador no Server 2
echo "1️⃣  Corrigindo usuário replicador no Server 2..."
mysql -h$SERVER2_IP -uroot -pteste123 -e "
    DROP USER IF EXISTS 'replicador'@'%';
    CREATE USER 'replicador'@'%' IDENTIFIED WITH mysql_native_password BY 'teste123';
    GRANT REPLICATION SLAVE ON *.* TO 'replicador'@'%';
    GRANT SELECT ON *.* TO 'replicador'@'%';
    GRANT REPLICATION CLIENT ON *.* TO 'replicador'@'%';
    FLUSH PRIVILEGES;
" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Usuário replicador corrigido no Server 2"
else
    echo "❌ Erro ao corrigir usuário no Server 2"
    exit 1
fi

# 2. Corrigir usuário replicador no Server 1
echo ""
echo "2️⃣  Corrigindo usuário replicador no Server 1..."
mysql -h$SERVER1_IP -uroot -pteste123 -e "
    DROP USER IF EXISTS 'replicador'@'%';
    CREATE USER 'replicador'@'%' IDENTIFIED WITH mysql_native_password BY 'teste123';
    GRANT REPLICATION SLAVE ON *.* TO 'replicador'@'%';
    GRANT SELECT ON *.* TO 'replicador'@'%';
    GRANT REPLICATION CLIENT ON *.* TO 'replicador'@'%';
    FLUSH PRIVILEGES;
" 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Usuário replicador corrigido no Server 1"
else
    echo "❌ Erro ao corrigir usuário no Server 1"
    exit 1
fi

# 3. Testar conexões
echo ""
echo "3️⃣  Testando conexões..."
if mysql -h$SERVER2_IP -ureplicador -pteste123 -e "SELECT 'OK' as status;" > /dev/null 2>&1; then
    echo "✅ Conexão replicador -> Server 2 OK"
else
    echo "❌ Conexão replicador -> Server 2 FALHOU"
    exit 1
fi

if mysql -h$SERVER1_IP -ureplicador -pteste123 -e "SELECT 'OK' as status;" > /dev/null 2>&1; then
    echo "✅ Conexão replicador -> Server 1 OK"
else
    echo "❌ Conexão replicador -> Server 1 FALHOU"
    exit 1
fi

# 4. Parar toda replicação
echo ""
echo "4️⃣  Parando toda replicação..."
mysql -h$SERVER1_IP -uroot -pteste123 -e "STOP SLAVE; RESET SLAVE ALL;" 2>/dev/null
mysql -h$SERVER2_IP -uroot -pteste123 -e "STOP SLAVE; RESET SLAVE ALL;" 2>/dev/null

sleep 3

# 5. Obter posições dos masters
echo ""
echo "5️⃣  Obtendo posições atuais..."

# Posição do Server 1
SERVER1_STATUS=$(mysql -h$SERVER1_IP -uroot -pteste123 -e "SHOW MASTER STATUS\G" 2>/dev/null)
SERVER1_FILE=$(echo "$SERVER1_STATUS" | grep "File:" | awk '{print $2}')
SERVER1_POS=$(echo "$SERVER1_STATUS" | grep "Position:" | awk '{print $2}')
echo "Server 1: $SERVER1_FILE, Position: $SERVER1_POS"

# Posição do Server 2
SERVER2_STATUS=$(mysql -h$SERVER2_IP -uroot -pteste123 -e "SHOW MASTER STATUS\G" 2>/dev/null)
SERVER2_FILE=$(echo "$SERVER2_STATUS" | grep "File:" | awk '{print $2}')
SERVER2_POS=$(echo "$SERVER2_STATUS" | grep "Position:" | awk '{print $2}')
echo "Server 2: $SERVER2_FILE, Position: $SERVER2_POS"

# 6. Verificar GTID
echo ""
echo "6️⃣  Verificando GTID..."
GTID1=$(mysql -h$SERVER1_IP -uroot -pteste123 -e "SHOW VARIABLES LIKE 'gtid_mode';" 2>/dev/null | grep gtid_mode | awk '{print $2}')
GTID2=$(mysql -h$SERVER2_IP -uroot -pteste123 -e "SHOW VARIABLES LIKE 'gtid_mode';" 2>/dev/null | grep gtid_mode | awk '{print $2}')

echo "GTID Server 1: $GTID1"
echo "GTID Server 2: $GTID2"

# 7. Configurar replicação
echo ""
echo "7️⃣  Configurando replicação bidirecional..."

if [ "$GTID1" = "ON" ] && [ "$GTID2" = "ON" ]; then
    echo "📡 Usando GTID..."
    
    # Server 1 -> Server 2
    mysql -h$SERVER1_IP -uroot -pteste123 -e "
        CHANGE MASTER TO
            MASTER_HOST='$SERVER2_IP',
            MASTER_USER='replicador',
            MASTER_PASSWORD='teste123',
            MASTER_AUTO_POSITION=1;
        START SLAVE;
    " 2>/dev/null
    
    # Server 2 -> Server 1
    mysql -h$SERVER2_IP -uroot -pteste123 -e "
        CHANGE MASTER TO
            MASTER_HOST='$SERVER1_IP',
            MASTER_USER='replicador',
            MASTER_PASSWORD='teste123',
            MASTER_AUTO_POSITION=1;
        START SLAVE;
    " 2>/dev/null
else
    echo "📡 Usando posição manual..."
    
    # Server 1 -> Server 2
    mysql -h$SERVER1_IP -uroot -pteste123 -e "
        CHANGE MASTER TO
            MASTER_HOST='$SERVER2_IP',
            MASTER_USER='replicador',
            MASTER_PASSWORD='teste123',
            MASTER_LOG_FILE='$SERVER2_FILE',
            MASTER_LOG_POS=$SERVER2_POS;
        START SLAVE;
    " 2>/dev/null
    
    # Server 2 -> Server 1
    mysql -h$SERVER2_IP -uroot -pteste123 -e "
        CHANGE MASTER TO
            MASTER_HOST='$SERVER1_IP',
            MASTER_USER='replicador',
            MASTER_PASSWORD='teste123',
            MASTER_LOG_FILE='$SERVER1_FILE',
            MASTER_LOG_POS=$SERVER1_POS;
        START SLAVE;
    " 2>/dev/null
fi

echo "✅ Replicação configurada"

# 8. Aguardar estabilização
echo ""
echo "8️⃣  Aguardando estabilização (30 segundos)..."
sleep 30

# 9. Status final
echo ""
echo "📊 STATUS FINAL DA REPLICAÇÃO:"
echo "============================="

echo ""
echo "🖥️  Server 1 Status:"
S1_IO=$(mysql -h$SERVER1_IP -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running:" | awk '{print $2}')
S1_SQL=$(mysql -h$SERVER1_IP -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_SQL_Running:" | awk '{print $2}')
S1_LAG=$(mysql -h$SERVER1_IP -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Seconds_Behind_Master:" | awk '{print $2}')

echo "   I/O Running: $S1_IO"
echo "   SQL Running: $S1_SQL"
echo "   Lag: ${S1_LAG}s"

echo ""
echo "🖥️  Server 2 Status:"
S2_IO=$(mysql -h$SERVER2_IP -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_IO_Running:" | awk '{print $2}')
S2_SQL=$(mysql -h$SERVER2_IP -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Slave_SQL_Running:" | awk '{print $2}')
S2_LAG=$(mysql -h$SERVER2_IP -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep "Seconds_Behind_Master:" | awk '{print $2}')

echo "   I/O Running: $S2_IO"
echo "   SQL Running: $S2_SQL"
echo "   Lag: ${S2_LAG}s"

echo ""
if [ "$S1_IO" = "Yes" ] && [ "$S1_SQL" = "Yes" ] && [ "$S2_IO" = "Yes" ] && [ "$S2_SQL" = "Yes" ]; then
    echo "🎉 REPLICAÇÃO BIDIRECIONAL FUNCIONANDO PERFEITAMENTE!"
    echo ""
    echo "✅ Teste agora:"
    echo "   1. Crie um banco no Server 1: CREATE DATABASE teste_server1_$(date +%s);"
    echo "   2. Verifique se aparece no Server 2"
    echo "   3. Crie um banco no Server 2: CREATE DATABASE teste_server2_$(date +%s);"
    echo "   4. Verifique se aparece no Server 1"
else
    echo "⚠️  Replicação ainda com problemas:"
    echo "   Server 1: I/O=$S1_IO, SQL=$S1_SQL"
    echo "   Server 2: I/O=$S2_IO, SQL=$S2_SQL"
    echo ""
    echo "🔍 Verifique os logs com: SHOW SLAVE STATUS\\G;"
fi

echo ""
echo "✅ Configuração completa finalizada!"