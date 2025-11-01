# 🖥️ MySQL Master 1 - Servidor de Produção

Configuração e execução do primeiro Master da replicação bidirecional.

## 📁 Estrutura

```
server-1/
├── docker-compose.yml          # Configuração Docker
├── .env                         # Variáveis de ambiente
├── myql/
│   └── my-config-1.cnf         # Configuração MySQL
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
mysql-master-1         Up ... (healthy)
phpmyadmin             Up ...
```

### 3. Aguardar Container Ficar Pronto

```bash
sleep 30
```

### 4. Configurar Replicação

```bash
cd exec
./setup-replication.sh <IP_MASTER_2>
```

Exemplos:
```bash
# Para servidores separados
./setup-replication.sh 192.168.1.20

# Para Docker local
./setup-replication.sh mysql-master-2
```

## 📊 Verificar Status

### Health Check
```bash
docker-compose ps
```

### Status da Replicação
```bash
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host|Master_Port)"
```

Saída esperada:
```
Slave_IO_Running: Yes
Slave_SQL_Running: Yes
Seconds_Behind_Master: 0
Master_Host: 192.168.1.20
Master_Port: 3306
```

### Logs
```bash
docker logs mysql-master-1 | tail -50
```

## 🔧 Configuração MySQL

**Arquivo**: `myql/my-config-1.cnf`

### Parâmetros Principais

| Parâmetro | Valor | Descrição |
|-----------|-------|-----------|
| `server-id` | 1 | ID único do servidor |
| `log-bin` | mysql-bin | Ativa binary logging |
| `log-slave-updates` | 1 | Propaga mudanças para o slave |
| `gtid_mode` | ON | GTID-based replication |
| `enforce_gtid_consistency` | ON | Força consistência GTID |
| `auto-increment-increment` | 2 | Incremento de 2 em 2 |
| `auto-increment-offset` | 1 | Começa com valores ímpares (1,3,5..) |

### Alterar Configuração

1. Edite `myql/my-config-1.cnf`
2. Reinicie o container:
```bash
docker-compose restart mysql-master-1
```

## 🌐 Acesso ao MySQL

### Via CLI
```bash
docker exec -it mysql-master-1 mysql -uroot -pteste123
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
docker exec mysql-master-1 mysql -uroot -pteste123 -e "ALTER USER 'root'@'localhost' IDENTIFIED BY 'nova_senha';"
```

### Firewall (UFW)

```bash
# Permitir apenas Master 2
sudo ufw allow from 192.168.1.20 to any port 3306

# Bloquear outros
sudo ufw deny from any to any port 3306
```

## 📊 Monitorar Replicação

### Em tempo real
```bash
watch -n 1 'docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master)"'
```

### GTID Status
```bash
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SELECT @@global.gtid_executed;"
```

## 🆘 Troubleshooting

### Problema: Container não inicia

```bash
# Ver logs
docker-compose logs mysql-master-1

# Verificar porta 3306
netstat -tuln | grep 3306

# Liberar porta
sudo lsof -i :3306
```

### Problema: Replicação não conecta

```bash
# Verificar conectividade
docker exec mysql-master-1 ping 192.168.1.20

# Testar acesso MySQL
docker exec mysql-master-1 mysql -h192.168.1.20 -ureplicador -pteste123

# Ver erro
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep Last_IO_Error
```

### Problema: Reiniciar Replicação

```bash
docker exec mysql-master-1 mysql -uroot -pteste123 -e "
STOP SLAVE;
RESET SLAVE ALL;
"

# Depois reexecute
cd exec
./setup-replication.sh 192.168.1.20
```

## 💾 Backup e Restore

### Backup Completo
```bash
docker exec mysql-master-1 mysqldump -uroot -pteste123 --all-databases > backup_master1_$(date +%Y%m%d_%H%M%S).sql
```

### Backup de um banco específico
```bash
docker exec mysql-master-1 mysqldump -uroot -pteste123 db_test > backup_db_test.sql
```

### Restaurar Backup
```bash
docker exec -i mysql-master-1 mysql -uroot -pteste123 < backup_master1.sql
```

## 🗑️ Limpeza

### Remover Container
```bash
docker-compose down
```

### Remover Volume (dados)
```bash
docker volume rm server-1_mysql-master-1-data
```

### Limpar tudo
```bash
docker-compose down -v
```

## 📝 Logs Importantes

### Erros de Replicação
```bash
docker logs mysql-master-1 2>&1 | grep -i "error"
```

### Conexões
```bash
docker logs mysql-master-1 2>&1 | grep -i "connection"
```

### GTID
```bash
docker logs mysql-master-1 2>&1 | grep -i "gtid"
```

## 🔄 Próximas Etapas

1. ✅ Container rodando
2. ✅ Replicação configurada
3. ⏭️ Configurar Master 2 (servidor-2)
4. ⏭️ Testar failover
5. ⏭️ Implementar backups automáticos

---

**Versão**: 0.5  
**Status**: ✅ Operacional
