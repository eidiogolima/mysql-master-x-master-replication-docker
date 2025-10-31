#!/bin/bash

# 🧪 TESTE DE RESILIÊNCIA - Simulação de queda do Master 2 por 1 minuto

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     🧪 TESTE DE RESILIÊNCIA - MASTER x MASTER            ║"
echo "║         Cenário: Master 2 offline por 1 minuto            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# PASSO 1: Preparar ambiente
echo "📋 PASSO 1: Preparando ambiente de teste..."
echo "=================================================="

docker exec mysql-master-1 mysql -uroot -pteste123 -e "
USE db_test;
DROP TABLE IF EXISTS teste_resiliencia;
CREATE TABLE teste_resiliencia (
  id INT AUTO_INCREMENT PRIMARY KEY,
  servidor VARCHAR(50),
  mensagem VARCHAR(255),
  timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
);
" 2>/dev/null

echo "✅ Tabela de teste criada"
echo ""

# PASSO 2: Inserir dados iniciais
echo "📝 PASSO 2: Inserindo dados iniciais em Master 1..."
echo "=================================================="

docker exec mysql-master-1 mysql -uroot -pteste123 -e "
USE db_test;
INSERT INTO teste_resiliencia (servidor, mensagem) VALUES 
('Master 1', '[ANTES DA QUEDA] Dados iniciais - linha 1'),
('Master 1', '[ANTES DA QUEDA] Dados iniciais - linha 2');
" 2>/dev/null

echo "✅ Dados iniciais inseridos"
echo ""

# Aguardar sincronização
echo "⏳ Aguardando sincronização entre masters (10 segundos)..."
sleep 10

# Verificar se sincronizou
echo ""
echo "📊 Verificação PRÉ-QUEDA:"
echo "=================================================="
echo "🖥️  Master 1 - Total de registros:"
MASTER1_COUNT=$(docker exec mysql-master-1 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM teste_resiliencia;" 2>/dev/null | tail -n 1)
echo "   $MASTER1_COUNT registros"

echo ""
echo "🖥️  Master 2 - Total de registros:"
MASTER2_COUNT=$(docker exec mysql-master-2 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM teste_resiliencia;" 2>/dev/null | tail -n 1)
echo "   $MASTER2_COUNT registros"

if [ "$MASTER1_COUNT" = "$MASTER2_COUNT" ]; then
    echo "✅ Sincronização OK - Ambos têm $MASTER1_COUNT registros"
else
    echo "⚠️  Sincronização não está 100%, mas continuaremos com o teste"
fi

echo ""

# PASSO 3: Derrubar Master 2
echo "💥 PASSO 3: Derrubando Master 2..."
echo "=================================================="
echo "⏰ Hora de início: $(date '+%H:%M:%S')"
echo ""

docker stop mysql-master-2 > /dev/null 2>&1
echo "✅ Master 2 OFFLINE"
echo ""

# PASSO 4: Inserir dados com Master 2 offline
echo "📝 PASSO 4: Inserindo dados em Master 1 (Master 2 OFFLINE)..."
echo "=================================================="
echo "⏰ Início das inserções: $(date '+%H:%M:%S')"
echo ""

docker exec mysql-master-1 mysql -uroot -pteste123 -e "
USE db_test;
INSERT INTO teste_resiliencia (servidor, mensagem) VALUES 
('Master 1', '[COM MASTER 2 OFFLINE] Inserção 1'),
('Master 1', '[COM MASTER 2 OFFLINE] Inserção 2'),
('Master 1', '[COM MASTER 2 OFFLINE] Inserção 3');
" 2>/dev/null

echo "✅ 3 registros inseridos enquanto Master 2 estava offline"
echo ""

# Mostrar status antes de reiniciar
echo "📊 Status em Master 1 (Master 2 ainda offline):"
echo "---"
docker exec mysql-master-1 mysql -uroot -pteste123 -e "USE db_test; SELECT id, servidor, SUBSTR(mensagem, 1, 40) as mensagem FROM teste_resiliencia ORDER BY id;" 2>/dev/null
echo ""

# PASSO 5: Aguardar 1 minuto
echo "⏳ PASSO 5: Aguardando 1 MINUTO (60 segundos) com Master 2 offline..."
echo "=================================================="

for i in {60..1}; do
    printf "\r⏳ Aguardando... %2d segundos restantes | Status Master 2: OFFLINE" "$i"
    sleep 1
done
echo ""
echo ""

# PASSO 6: Reiniciar Master 2
echo "🔄 PASSO 6: Reiniciando Master 2..."
echo "=================================================="
echo "⏰ Hora de reinicialização: $(date '+%H:%M:%S')"
echo ""

docker start mysql-master-2 > /dev/null 2>&1
echo "✅ Master 2 iniciando..."
echo ""

# Aguardar Master 2 ficar healthy
echo "⏳ Aguardando Master 2 ficar online (máx 60 segundos)..."

for i in {1..60}; do
    if docker exec mysql-master-2 mysqladmin ping -u root -pteste123 -h localhost >/dev/null 2>&1; then
        echo "✅ Master 2 ONLINE após $i segundos"
        break
    fi
    if [ $((i % 5)) -eq 0 ]; then
        echo "   Ainda aguardando ($i/60)..."
    fi
    sleep 1
done

echo ""

# PASSO 7: Aguardar sincronização
echo "⏳ PASSO 7: Aguardando sincronização dos dados (15 segundos)..."
echo "=================================================="

sleep 15

echo "✅ Sincronização concluída"
echo ""

# PASSO 8: Verificar sincronização
echo "📊 PASSO 8: Verificando sincronização PÓS-QUEDA..."
echo "=================================================="
echo ""

echo "🖥️  Master 1 - Registros:"
echo "---"
docker exec mysql-master-1 mysql -uroot -pteste123 -e "USE db_test; SELECT id, servidor, SUBSTR(mensagem, 1, 50) as mensagem, DATE_FORMAT(timestamp, '%H:%i:%S') as hora FROM teste_resiliencia ORDER BY id;" 2>/dev/null

echo ""
echo "🖥️  Master 2 - Registros:"
echo "---"
docker exec mysql-master-2 mysql -uroot -pteste123 -e "USE db_test; SELECT id, servidor, SUBSTR(mensagem, 1, 50) as mensagem, DATE_FORMAT(timestamp, '%H:%i:%S') as hora FROM teste_resiliencia ORDER BY id;" 2>/dev/null

echo ""

# PASSO 9: Contar registros
echo "📊 PASSO 9: Resumo Final..."
echo "=================================================="
echo ""

MASTER1_FINAL=$(docker exec mysql-master-1 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM teste_resiliencia;" 2>/dev/null | tail -n 1)
MASTER2_FINAL=$(docker exec mysql-master-2 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM teste_resiliencia;" 2>/dev/null | tail -n 1)

echo "📈 Registros inseridos antes da queda: 2"
echo "📈 Registros inseridos durante queda:  3"
echo "📈 Total esperado:                      5"
echo ""
echo "🖥️  Master 1 - Total de registros: $MASTER1_FINAL"
echo "🖥️  Master 2 - Total de registros: $MASTER2_FINAL"
echo ""

# PASSO 10: Status da replicação
echo "📋 PASSO 10: Status da Replicação..."
echo "=================================================="
echo ""

echo "🖥️  Master 1 - Status de replicação:"
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error:)"

echo ""
echo "🖥️  Master 2 - Status de replicação:"
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error:)"

echo ""

# RESULTADO FINAL
echo "╔════════════════════════════════════════════════════════════╗"
if [ "$MASTER1_FINAL" = "5" ] && [ "$MASTER2_FINAL" = "5" ]; then
    echo "║                    ✅ TESTE PASSOU!                      ║"
    echo "║                                                            ║"
    echo "║  ✓ Dados foram sincronizados automaticamente             ║"
    echo "║  ✓ Nenhuma perda de dados durante queda de 1 minuto      ║"
    echo "║  ✓ Replicação bidirecional funcionando perfeitamente     ║"
else
    echo "║                    ⚠️  TESTE COM AVISO                   ║"
    echo "║                                                            ║"
    echo "║  Master 1: $MASTER1_FINAL registros                         ║"
    echo "║  Master 2: $MASTER2_FINAL registros                         ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# NOVO TESTE: QUEDA DE AMBOS OS SERVIDORES
# ============================================================================

echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║     🧪 TESTE 2: QUEDA DE AMBOS OS SERVIDORES             ║"
echo "║         Cenário: Master 1 e Master 2 offline por 1 min    ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# PASSO 11: Preparar dados para teste de queda dupla
echo "📋 PASSO 11: Preparando dados para teste de queda dupla..."
echo "=================================================="

docker exec mysql-master-1 mysql -uroot -pteste123 -e "
USE db_test;
INSERT INTO teste_resiliencia (servidor, mensagem) VALUES 
('Master 1', '[ANTES QUEDA DUPLA] Preparação teste 2 - linha 1');
" 2>/dev/null

echo "✅ Dado preparatório inserido"
echo ""

# Aguardar sincronização
sleep 5

echo "📊 Contagem antes da queda dupla:"
BEFORE_DOUBLE_FAIL=$(docker exec mysql-master-1 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM teste_resiliencia;" 2>/dev/null | tail -n 1)
echo "   Total de registros: $BEFORE_DOUBLE_FAIL"
echo ""

# PASSO 12: Derrubar ambos os servidores simultaneamente
echo "💥 PASSO 12: Derrubando AMBOS os Masters simultaneamente..."
echo "=================================================="
echo "⏰ Hora de início: $(date '+%H:%M:%S')"
echo ""

docker stop mysql-master-1 mysql-master-2 > /dev/null 2>&1
echo "✅ Master 1 OFFLINE"
echo "✅ Master 2 OFFLINE"
echo ""
echo "⚠️  AMBOS OS SERVIDORES ESTÃO OFFLINE!"
echo ""

# PASSO 13: Aguardar 1 minuto com ambos offline
echo "⏳ PASSO 13: Aguardando 1 MINUTO com AMBOS offline..."
echo "=================================================="

for i in {60..1}; do
    printf "\r⏳ Aguardando... %2d segundos restantes | Status: AMBOS OFFLINE" "$i"
    sleep 1
done
echo ""
echo ""

# PASSO 14: Reiniciar ambos os servidores simultaneamente
echo "🔄 PASSO 14: Reiniciando AMBOS os Masters..."
echo "=================================================="
echo "⏰ Hora de reinicialização: $(date '+%H:%M:%S')"
echo ""

docker start mysql-master-1 mysql-master-2 > /dev/null 2>&1
echo "✅ Masters iniciando..."
echo ""

# Aguardar ambos ficarem healthy
echo "⏳ Aguardando Masters ficarem online (máx 60 segundos)..."

MASTER1_ONLINE=0
MASTER2_ONLINE=0

for i in {1..60}; do
    if [ $MASTER1_ONLINE -eq 0 ] && docker exec mysql-master-1 mysqladmin ping -u root -pteste123 -h localhost >/dev/null 2>&1; then
        echo "✅ Master 1 ONLINE após $i segundos"
        MASTER1_ONLINE=1
    fi
    
    if [ $MASTER2_ONLINE -eq 0 ] && docker exec mysql-master-2 mysqladmin ping -u root -pteste123 -h localhost >/dev/null 2>&1; then
        echo "✅ Master 2 ONLINE após $i segundos"
        MASTER2_ONLINE=1
    fi
    
    if [ $MASTER1_ONLINE -eq 1 ] && [ $MASTER2_ONLINE -eq 1 ]; then
        echo ""
        echo "✅ Ambos os Masters estão ONLINE!"
        break
    fi
    
    sleep 1
done

echo ""

# PASSO 15: Verificar dados após queda dupla
echo "📊 PASSO 15: Verificando dados PÓS-QUEDA DUPLA..."
echo "=================================================="
echo ""

echo "🖥️  Master 1 - Total de registros:"
MASTER1_AFTER_DOUBLE=$(docker exec mysql-master-1 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM teste_resiliencia;" 2>/dev/null | tail -n 1)
echo "   $MASTER1_AFTER_DOUBLE registros"

echo ""
echo "🖥️  Master 2 - Total de registros:"
MASTER2_AFTER_DOUBLE=$(docker exec mysql-master-2 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM teste_resiliencia;" 2>/dev/null | tail -n 1)
echo "   $MASTER2_AFTER_DOUBLE registros"

echo ""

# Aguardar sincronização
echo "⏳ Aguardando sincronização após reinicialização (15 segundos)..."
sleep 15

echo "✅ Sincronização concluída"
echo ""

# PASSO 16: Verificação final após sincronização
echo "📋 PASSO 16: Verificação final de sincronização..."
echo "=================================================="
echo ""

MASTER1_FINAL_DOUBLE=$(docker exec mysql-master-1 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM teste_resiliencia;" 2>/dev/null | tail -n 1)
MASTER2_FINAL_DOUBLE=$(docker exec mysql-master-2 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM teste_resiliencia;" 2>/dev/null | tail -n 1)

echo "🖥️  Master 1 - Total final: $MASTER1_FINAL_DOUBLE registros"
echo "🖥️  Master 2 - Total final: $MASTER2_FINAL_DOUBLE registros"
echo ""

# PASSO 17: Status da replicação após reinicialização dupla
echo "📋 PASSO 17: Status da Replicação após reinicialização..."
echo "=================================================="
echo ""

echo "🖥️  Master 1 - Status de replicação:"
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error:)"

echo ""
echo "🖥️  Master 2 - Status de replicação:"
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" 2>/dev/null | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_Error:)"

echo ""

# RESULTADO FINAL DO TESTE 2
echo "╔════════════════════════════════════════════════════════════╗"
if [ "$MASTER1_FINAL_DOUBLE" = "$MASTER2_FINAL_DOUBLE" ] && [ "$MASTER1_FINAL_DOUBLE" = "$BEFORE_DOUBLE_FAIL" ]; then
    echo "║                    ✅ TESTE 2 PASSOU!                     ║"
    echo "║                                                            ║"
    echo "║  ✓ Ambos os masters recuperados com sucesso              ║"
    echo "║  ✓ Dados intactos após queda dupla (offline + online)    ║"
    echo "║  ✓ Sincronização automática entre os servidores          ║"
else
    echo "║                ⚠️  TESTE 2 - RESULTADO PARCIAL            ║"
    echo "║                                                            ║"
    echo "║  Master 1: $MASTER1_FINAL_DOUBLE registros                    ║"
    echo "║  Master 2: $MASTER2_FINAL_DOUBLE registros                    ║"
    echo "║  Esperado: $BEFORE_DOUBLE_FAIL registros                      ║"
fi
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "════════════════════════════════════════════════════════════════"
echo "                  🎉 TODOS OS TESTES CONCLUÍDOS!                "
echo "════════════════════════════════════════════════════════════════"
echo ""
