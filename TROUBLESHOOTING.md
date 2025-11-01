# 🆘 Troubleshooting e FAQs

Guia de resolução de problemas comuns na replicação MySQL Master x Master.

## ❌ Problemas Comuns

### 1. Slave_IO_Running = No/Connecting

**Sintoma**:
```
Slave_IO_Running: No
Slave_SQL_Running: Yes
Last_IO_Error: Can't connect to MySQL server on '192.168.1.20'
```

**Causas possíveis**:
- IP incorreto
- Conectividade de rede com problema
- Firewall bloqueando porta 3306
- Container MySQL do outro servidor não está rodando

**Solução**:

1️⃣ **Verificar conectividade de rede**:
```bash
# Test ping
docker exec mysql-master-1 ping 192.168.1.20

# Test conexão MySQL
docker exec mysql-master-1 mysql -h192.168.1.20 -ureplicador -pteste123 -e "SELECT 1;"
```

2️⃣ **Verificar se container está rodando**:
```bash
# No outro servidor
docker-compose ps
# Procure por "healthy"
```

3️⃣ **Verificar firewall**:
```bash
# No servidor de destino
sudo ufw status
sudo ufw allow from 192.168.1.10 to any port 3306
```

4️⃣ **Reiniciar replicação**:
```bash
docker exec mysql-master-1 mysql -uroot -pteste123 -e "
STOP SLAVE;
RESET SLAVE ALL;
"

# Depois reexecute script
cd exec
./setup-replication.sh 192.168.1.20
```

---

### 2. Slave_SQL_Running = No

**Sintoma**:
```
Slave_IO_Running: Yes
Slave_SQL_Running: No
Last_SQL_Error: Error 'Duplicate entry' on query...
```

**Causas possíveis**:
- Conflito de chave primária
- Erro de SQL não resolvido
- Inconsistência de dados

**Solução**:

1️⃣ **Ver erro específico**:
```bash
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep Last_SQL_Error
```

2️⃣ **Se for conflito de PK**:
```bash
# Pular erro (CUIDADO!)
docker exec mysql-master-1 mysql -uroot -pteste123 -e "
SET GLOBAL SQL_SLAVE_SKIP_COUNTER = 1;
START SLAVE;
"
```

3️⃣ **Se for erro crítico** (resolver manualmente):
```bash
# Conectar e corrigir
docker exec -it mysql-master-1 mysql -uroot -pteste123

# Dentro do MySQL:
STOP SLAVE;
# ... corrigir dados conflitantes ...
START SLAVE;
```

4️⃣ **Último recurso** (resetar replicação):
```bash
# ⚠️ CUIDADO: Isso perde histórico de replicação
docker exec mysql-master-1 mysql -uroot -pteste123 -e "
RESET SLAVE ALL;
"

# Reconfigurar
cd exec
./setup-replication.sh 192.168.1.20
```

---

### 3. Seconds_Behind_Master = NULL

**Sintoma**:
```
Seconds_Behind_Master: NULL
```

**Significado**: Replicação não foi iniciada ou está desconectada

**Solução**:
```bash
# Verificar status completo
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G"

# Se Slave_IO_Running = No, resolver conforme seção 1 (acima)
```

---

### 4. Container não inicia

**Sintoma**:
```
ERROR: for mysql-master-1  Cannot start service mysql-master-1: ...
```

**Causas possíveis**:
- Porta 3306 já em uso
- Problemas de volume
- Erro no arquivo de configuração

**Solução**:

1️⃣ **Ver logs detalhados**:
```bash
docker-compose logs mysql-master-1 | tail -100
```

2️⃣ **Verificar porta em uso**:
```bash
sudo netstat -tuln | grep 3306
sudo lsof -i :3306
```

3️⃣ **Liberar porta** (se necessário):
```bash
# Matar processo na porta
sudo kill -9 <PID>

# Ou usar porta diferente no docker-compose.yml
ports:
  - '3307:3306'  # Mudar aqui
```

4️⃣ **Verificar arquivo de configuração**:
```bash
# Validar sintaxe do my.cnf
docker run --rm -v $(pwd)/myql:/etc/mysql mysql:8.0 /bin/bash -c "cat /etc/mysql/conf.d/my.cnf"
```

5️⃣ **Limpar tudo e começar novamente**:
```bash
docker-compose down -v
docker-compose up -d
```

---

### 5. Auto-increment gerando conflitos

**Sintoma**:
```
Duplicate entry '5' for key 'PRIMARY'
```

**Causa**: Ambos os masters gerando o mesmo ID

**Solução**: Verificar `auto-increment-offset` em my-config.cnf

**Master 1** deve ter:
```ini
auto-increment-increment = 2
auto-increment-offset = 1       # IDs: 1, 3, 5, 7...
```

**Master 2** deve ter:
```ini
auto-increment-increment = 2
auto-increment-offset = 2       # IDs: 2, 4, 6, 8...
```

Se estiver errado:
1. Editar arquivo .cnf
2. Reiniciar container: `docker-compose restart mysql-master-1`
3. Reconfigurar replicação

---

### 6. GTID desincronizado

**Sintoma**:
```
@@global.gtid_executed: diferente em cada server
```

**Verificar**:
```bash
# Master 1
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SELECT @@global.gtid_executed;"

# Master 2
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SELECT @@global.gtid_executed;"
```

**Solução**:
```bash
# Reiniciar replicação em ambos
docker exec mysql-master-1 mysql -uroot -pteste123 -e "
STOP SLAVE;
RESET SLAVE ALL;
"

docker exec mysql-master-2 mysql -uroot -pteste123 -e "
STOP SLAVE;
RESET SLAVE ALL;
"

# Reconfigurar
cd server-1/exec && ./setup-replication.sh 192.168.1.20
cd server-2/exec && ./setup-replication.sh 192.168.1.10
```

---

### 7. Dados não replicando

**Sintoma**:
```
# Master 1
CREATE DATABASE test;

# Master 2 - banco não aparece
SHOW DATABASES;
```

**Diagnóstico**:
```bash
# 1. Verificar se replicação está ativa
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "Running|Master"

docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "Running|Master"

# 2. Verificar lag
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep "Seconds_Behind"

docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep "Seconds_Behind"

# 3. Ver logs
docker logs mysql-master-1 | tail -50
docker logs mysql-master-2 | tail -50
```

**Solução**:
- Se lag > 0: aguardar sincronização
- Se algum está "No": resolver seções acima
- Se "Connecting": verificar conectividade

---

### 8. phpMyAdmin não conecta

**Sintoma**:
```
Cannot connect to MySQL server
```

**Solução**:

1️⃣ **Verificar se MySQL está rodando**:
```bash
docker-compose ps
# mysql-master-1 deve estar "healthy"
```

2️⃣ **Verificar logs**:
```bash
docker logs phpmyadmin | tail -20
docker logs mysql-master-1 | tail -20
```

3️⃣ **Tentar acesso direto**:
```bash
docker exec -it mysql-master-1 mysql -uroot -pteste123 -e "SELECT 1;"
```

4️⃣ **Reiniciar phpMyAdmin**:
```bash
docker-compose restart phpmyadmin
```

---

## ⚙️ Comandos Úteis

### Status Geral

```bash
# Ambos os containers rodando?
docker-compose ps

# Logs?
docker logs mysql-master-1
docker logs mysql-master-2



```

### MySQL CLI

```bash
# Conectar ao Master 1
docker exec -it mysql-master-1 mysql -uroot -pteste123

# Conectar ao Master 2
docker exec -it mysql-master-2 mysql -uroot -pteste123

# Executar query
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW DATABASES;"
```

### Reiniciar Replicação

```bash
# Parar
docker exec mysql-master-1 mysql -uroot -pteste123 -e "STOP SLAVE;"

# Resetar
docker exec mysql-master-1 mysql -uroot -pteste123 -e "RESET SLAVE ALL;"

# Reconfigurar
cd exec
./setup-replication.sh 192.168.1.20

# Iniciar
docker exec mysql-master-1 mysql -uroot -pteste123 -e "START SLAVE;"
```

### Backup Rápido

```bash
# Master 1
docker exec mysql-master-1 mysqldump -uroot -pteste123 --all-databases > backup_m1.sql

# Master 2
docker exec mysql-master-2 mysqldump -uroot -pteste123 --all-databases > backup_m2.sql

# Restaurar
docker exec -i mysql-master-1 mysql -uroot -pteste123 < backup_m1.sql
```

### Limpeza Completa

```bash
# Desligar
docker-compose down

# Remover volumes
docker volume rm server-1_mysql-master-1-data

# Listar logs antigos
docker logs mysql-master-1 | wc -l

# Limpar tudo
docker-compose down -v
docker system prune -a -f
```

---

## 📊 Debug Checklist

Quando tiver problemas, execute nesta ordem:

- [ ] `docker-compose ps` - Containers rodando?
- [ ] `docker logs mysql-master-1` - Erros no log?
- [ ] `docker exec mysql-master-1 mysql -uroot -pteste123 -e "SELECT 1;"` - MySQL responde?
- [ ] `docker exec mysql-master-1 ping 192.168.1.20` - Rede OK?
- [ ] `docker exec mysql-master-1 mysql -h192.168.1.20 -ureplicador -pteste123 -e "SELECT 1;"` - Consegue conectar?
- [ ] `docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G"` - Status da replicação?
- [ ] `` - Tudo sincronizado?

---

## 📞 Escalação

Se nada funcionar:

1. **Coletar informações**:
```bash
# Criar arquivo de debug
{
  echo "=== DOCKER COMPOSE PS ==="
  docker-compose ps
  
  echo ""
  echo "=== LOGS MASTER 1 ==="
  docker logs mysql-master-1 | tail -50
  
  echo ""
  echo "=== LOGS MASTER 2 ==="
  docker logs mysql-master-2 | tail -50
  
  echo ""
  echo "=== SLAVE STATUS MASTER 1 ==="
  docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G"
  
  echo ""
  echo "=== SLAVE STATUS MASTER 2 ==="
  docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G"
} > debug_info.txt
```

2. **Compartilhar arquivo `debug_info.txt` para suporte**

---

**Última atualização**: 31 de outubro de 2025  
**Versão**: 0.5
