# 🚀 Guia de Setup Rápido - Produção

Deploy do MySQL Master x Master com GTID em dois servidores separados.

## 📋 Pré-requisitos

- Docker instalado em ambos os servidores
- Docker Compose instalado
- IPs conhecidos de ambos os servidores
- Portas 3306 abertas (entre os servidores)

## 🖥️ Exemplo de Configuração

```
Servidor 1 (Master 1)
├─ IP: 192.168.1.10
├─ Docker rodando
└─ Porta 3306 aberta

Servidor 2 (Master 2)
├─ IP: 192.168.1.20
├─ Docker rodando
└─ Porta 3306 aberta
```

## 📝 Passo 1: Clonar/Preparar Repositório

### No Servidor 1:
```bash
cd ~/projects
git clone <seu-repo> mysql-replication
cd mysql-replication/prod/server-1
```

### No Servidor 2:
```bash
cd ~/projects
git clone <seu-repo> mysql-replication
cd mysql-replication/prod/server-2
```

## ⚙️ Passo 2: Configurar Variáveis de Ambiente

### No Servidor 1:
```bash
cat > .env << EOF
DB_ROOT_PASSWORD=SuaSenhaForte123!
DB_PASSWORD=SenhaReplicador456!
EOF

chmod 600 .env
```

### No Servidor 2:
```bash
cat > .env << EOF
DB_ROOT_PASSWORD=SuaSenhaForte123!
DB_PASSWORD=SenhaReplicador456!
EOF

chmod 600 .env
```

> **⚠️ IMPORTANTE**: Use as MESMAS senhas em ambos os servidores!

## 🐳 Passo 3: Subir os Containers

### No Servidor 1:
```bash
docker-compose up -d

# Verificar
docker-compose ps
# Esperado: mysql-master-1 e phpmyadmin com status "healthy"
```

### No Servidor 2:
```bash
docker-compose up -d

# Verificar
docker-compose ps
# Esperado: mysql-master-2 e phpmyadmin com status "healthy"
```

## ⏳ Passo 4: Aguardar Containers Ficarem Prontos

Ambos os servidores:
```bash
sleep 30
```

Ou verificar manualmente:
```bash
docker-compose logs mysql-master-1 | tail -20
docker-compose logs mysql-master-2 | tail -20
```

Procure por: `ready for connections`

## 🔄 Passo 5: Configurar Replicação Master 1

### No Servidor 1:
```bash
cd exec
./setup-replication.sh 192.168.1.20
```

Saída esperada:
```
✅ Usuário criado no Master 1
✅ Master 1 configurado para replicar
✅ Slave_IO_Running: Yes
✅ Slave_SQL_Running: Yes
🎉 Replicação ATIVA no Master 1!
```

## 🔄 Passo 6: Configurar Replicação Master 2

### No Servidor 2:
```bash
cd exec
./setup-replication.sh 192.168.1.10
```

Saída esperada:
```
✅ Usuário criado no Master 2
✅ Master 2 configurado para replicar
✅ Slave_IO_Running: Yes
✅ Slave_SQL_Running: Yes
🎉 Replicação ATIVA no Master 2!
✅ REPLICAÇÃO BIDIRECIONAL FUNCIONANDO!
```

## ✅ Passo 7: Verificar Status

### No Servidor 1:
```bash
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host)"
```

### No Servidor 2:
```bash
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep -E "(Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Master_Host)"
```

### Usar Script de Check (na raiz do prod/):
```bash

```

## 🧪 Passo 8: Testar Replicação

### No Servidor 1, criar um banco:
```bash
docker exec mysql-master-1 mysql -uroot -pteste123 -e "
CREATE DATABASE test_replication;
USE test_replication;
CREATE TABLE users (id INT PRIMARY KEY AUTO_INCREMENT, name VARCHAR(100));
INSERT INTO users (name) VALUES ('Alice');
"
```

### No Servidor 2, verificar se apareceu:
```bash
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW DATABASES;"
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SELECT * FROM test_replication.users;"
```

**Resultado esperado**: Banco e dados aparecem no Master 2 em menos de 5 segundos!

### No Servidor 2, inserir dado:
```bash
docker exec mysql-master-2 mysql -uroot -pteste123 -e "
USE test_replication;
INSERT INTO users (name) VALUES ('Bob');
"
```

### No Servidor 1, verificar:
```bash
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SELECT * FROM test_replication.users;"
```

**Resultado esperado**: Ambos os usuários (Alice e Bob) aparcem!

## 🌐 Passo 9: Acessar phpMyAdmin

### Servidor 1:
```
http://192.168.1.10:8085
Usuário: root
Senha: SuaSenhaForte123!
```

### Servidor 2:
```
http://192.168.1.20:8085
Usuário: root
Senha: SuaSenhaForte123!
```

## 🔐 Passo 10: Configurar Firewall

### No Servidor 1 (UFW):
```bash
# Permitir Master 2 acessar porta 3306
sudo ufw allow from 192.168.1.20 to any port 3306

# Bloquear outras conexões
sudo ufw deny from any to any port 3306

# Verificar
sudo ufw status
```

### No Servidor 2 (UFW):
```bash
# Permitir Master 1 acessar porta 3306
sudo ufw allow from 192.168.1.10 to any port 3306

# Bloquear outras conexões
sudo ufw deny from any to any port 3306

# Verificar
sudo ufw status
```

## 📊 Monitoramento Contínuo

### Ver logs em tempo real:
```bash
# Servidor 1
docker logs -f mysql-master-1

# Servidor 2
docker logs -f mysql-master-2
```

## automático a cada 5 segundos:
```bash
watch -n 5 ''
```

## 🆘 Troubleshooting Rápido

### Problema: Slave_IO_Running = Connecting

```bash
# Verificar conectividade
docker exec mysql-master-1 ping 192.168.1.20

# Testar MySQL
docker exec mysql-master-1 mysql -h192.168.1.20 -ureplicador -pteste123

# Ver erro específico
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G" | grep Last_IO_Error
```

### Problema: Containers não iniciam

```bash
# Ver logs detalhados
docker-compose logs mysql-master-1

# Verificar porta
sudo netstat -tuln | grep 3306

# Liberar porta se necessário
sudo lsof -i :3306
```

### Reiniciar replicação do zero

```bash
# Servidor 1
cd exec
./setup-replication.sh 192.168.1.20

# Servidor 2
cd exec
./setup-replication.sh 192.168.1.10
```

## ✨ Resumo dos Comandos

```bash
# SERVIDOR 1
cd ~/projects/mysql-replication/prod/server-1
cat > .env << EOF
DB_ROOT_PASSWORD=SuaSenhaForte123!
DB_PASSWORD=SenhaReplicador456!
EOF
docker-compose up -d
sleep 30
cd exec
./setup-replication.sh 192.168.1.20

# SERVIDOR 2
cd ~/projects/mysql-replication/prod/server-2
cat > .env << EOF
DB_ROOT_PASSWORD=SuaSenhaForte123!
DB_PASSWORD=SenhaReplicador456!
EOF
docker-compose up -d
sleep 30
cd exec
./setup-replication.sh 192.168.1.10



```

## 📚 Próximas Etapas Recomendadas

1. ✅ Setup concluído
2. ⏭️ Implementar backups automáticos
3. ⏭️ Configurar monitoramento (Prometheus/Grafana)
4. ⏭️ Testar failover manual
5. ⏭️ Configurar alertas

---

**Tempo estimado**: 15 minutos  
**Dificuldade**: ⭐⭐ Intermediária  
**Status**: ✅ Production Ready
