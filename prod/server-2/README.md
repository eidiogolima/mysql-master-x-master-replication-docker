# 🖥️ MySQL Master 2 - Servidor de Produção

Configuração e execução do segundo Master da replicação bidirecional.

## 📁 Estrutura

```
server-2/
├── docker-compose.yml          # Configuração Docker
├── .env                         # Variáveis de ambiente
├── mysql/
│   └── my-config-2.cnf         # Configuração MySQL
└── exec/
    └── setup-replication.sh    # Script de replicação
```

## 🚀 Quick Start

### 1. Preparar Variáveis de Ambiente

```bash
cat > .env << EOF
DB_ROOT_PASSWORD=teste123
DB_PASSWORD=teste123
EOF
```

### 2. Subir Container

```bash
docker-compose up -d
```

Verificar status:
```bash
docker-compose ps
```

Esperado:
```
NAME                   STATUS
mysql-master-2         Up ... (healthy)
phpmyadmin             Up ...
```

### 3. Aguardar Container Ficar Pronto

```bash
sleep 30
```

### 4. Configurar Replicação

**⚠️ IMPORTANTE**: Execute APÓS configurar o Master 1!

```bash
cd exec
./setup-replication.sh <IP_MASTER_1>
```

Exemplos:
```bash
# Para servidores separados
./setup-replication.sh 192.168.1.10

# Para Docker local
./setup-replication.sh mysql-master-1
```

## 📊 Verificar Status

### Health Check
```bash
docker-compose ps
```

### Status da Replicação
```bash
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host|Master_Port)"
```

Saída esperada:
```
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Seconds_Behind_Master: 0
Master_Host: 192.168.1.10
Master_Port: 3306
```

### Logs
```bash
docker logs mysql-master-2 | tail -50
```

## 🔧 Configuração MySQL

**Arquivo**: `mysql/my-config-2.cnf`

### Parâmetros Principais

| Parâmetro | Valor | Descrição |
|-----------|-------|-----------|
| `server-id` | 2 | ID único do servidor |
| `log-bin` | mysql-bin | Ativa binary logging |
| `log-slave-updates` | 1 | Propaga mudanças para o slave |
| `gtid_mode` | ON | GTID-based replication |
| `enforce_gtid_consistency` | ON | Força consistência GTID |
| `auto-increment-increment` | 2 | Incremento de 2 em 2 |
| `auto-increment-offset` | 2 | Começa com valores pares (2,4,6..) |

### Alterar Configuração

1. Edite `mysql/my-config-2.cnf`
2. Reinicie o container:
```bash
docker-compose restart mysql-master-2
```

## 🌐 Acesso ao MySQL

### Via CLI
```bash
docker exec -it mysql-master-2 mysql -uroot -pteste123
```

### Via phpMyAdmin
```
http://localhost:8085
Usuário: root
Senha: teste123
```

## 🔐 Segurança

### Mudar Senha Root

```bash
docker exec mysql-master-2 mysql -uroot -pteste123 -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'nova_senha';"
```

### Firewall (UFW)

```bash
# Permitir apenas Master 1
sudo ufw allow from 192.168.1.10 to any port 3306

# Bloquear outros
sudo ufw deny from any to any port 3306
```

## 📊 Monitorar Replicação

### Em tempo real
```bash
watch -n 1 'docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master)"'
```

### GTID Status
```bash
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SELECT @@global.gtid_executed;"
```

## 🆘 Troubleshooting

### Problema: Container não inicia

```bash
# Ver logs
docker-compose logs mysql-master-2

# Verificar porta 3306
netstat -tuln | grep 3306

# Liberar porta
sudo lsof -i :3306
```

### Problema: Replicação não conecta

```bash
# Verificar conectividade
docker exec mysql-master-2 ping 192.168.1.10

# Testar acesso MySQL
docker exec mysql-master-2 mysql -h192.168.1.10 -ureplicador -pteste123

# Ver erro
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep Last_IO_Error
```

### Problema: Reiniciar Replicação

```bash
docker exec mysql-master-2 mysql -uroot -pteste123 -e "
STOP SLAVE;
RESET SLAVE ALL;
"

# Depois reexecute
cd exec
./setup-replication.sh 192.168.1.10
```

## 💾 Backup e Restore

### Backup Completo
```bash
docker exec mysql-master-2 mysqldump -uroot -pteste123 --all-databases > backup_master2_$(date +%Y%m%d_%H%M%S).sql
```

### Backup de um banco específico
```bash
docker exec mysql-master-2 mysqldump -uroot -pteste123 db_test > backup_db_test.sql
```

### Restaurar Backup
```bash
docker exec -i mysql-master-2 mysql -uroot -pteste123 < backup_master2.sql
```

## 🗑️ Limpeza

### Remover Container
```bash
docker-compose down
```

### Remover Volume (dados)
```bash
docker volume rm server-2_mysql-master-2-data
```

### Limpar tudo
```bash
docker-compose down -v
```

## 📝 Logs Importantes

### Erros de Replicação
```bash
docker logs mysql-master-2 2>&1 | grep -i "error"
```

### Conexões
```bash
docker logs mysql-master-2 2>&1 | grep -i "connection"
```

### GTID
```bash
docker logs mysql-master-2 2>&1 | grep -i "gtid"
```

## 🔄 Próximas Etapas

1. ✅ Master 1 configurado
2. ✅ Container Master 2 rodando
3. ✅ Replicação bidirecional configurada
4. ⏭️ Testar failover
5. ⏭️ Implementar backups automáticos

---

**Versão**: 0.5  
**Status**: ✅ Operacional
