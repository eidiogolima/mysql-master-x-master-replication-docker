# ⚡ GUIA RÁPIDO - MySQL Master x Master com Docker

## 🚀 Iniciar em 3 passos

```bash
# 1. Subir os containers
docker-compose up -d

# 2. Configurar replicação
./setup-replication.sh

# 3. Acessar phpMyAdmin
# Abra: http://localhost:8085
```

## 📊 Verificar Status

```bash
./check-replication.sh
```

## 🧪 Testar Resiliência

```bash
./test-failover-resilience.sh
```

## 📋 Estrutura do Projeto

```
.
├── docker-compose.yml          # Definição dos serviços
├── docker/mysql/
│   ├── my-simple.cnf           # Config Master 1
│   └── my-simple-2.cnf         # Config Master 2
├── setup-replication.sh        # Setup automático
├── check-replication.sh        # Monitoramento
├── test-failover-resilience.sh # Testes
├── README.md                   # Documentação completa
├── NETWORK_ACCESS.md           # Acesso aos serviços
└── RELATORIO_TESTES_RESILIENCIA.md # Testes detalhados
```

## 🌐 Acessos

| Serviço | URL | Usuário | Senha |
|---------|-----|---------|-------|
| phpMyAdmin | http://localhost:8085 | root | teste123 |
| MySQL Master 1 | localhost:3306 (interno) | root | teste123 |
| MySQL Master 2 | localhost:3307 (interno) | root | teste123 |

## 🛠️ Comandos Úteis

```bash
# Ver logs
docker-compose logs mysql-master-1
docker-compose logs mysql-master-2

# Conectar ao MySQL Master 1
docker exec -it mysql-master-1 mysql -uroot -pteste123

# Conectar ao MySQL Master 2
docker exec -it mysql-master-2 mysql -uroot -pteste123

# Parar tudo
docker-compose down

# Remover dados (CUIDADO!)
docker-compose down -v
```

## 🔍 Diagnosticar Problemas

### Replicação não funciona?

```bash
# Verificar status
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G"

# Verificar usuário de replicação
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SELECT user, host FROM mysql.user WHERE user='replicador';"

# Ver logs do container
docker logs mysql-master-1
```

### Dados não sincronizam?

```bash
# Verificar data em ambos masters
docker exec mysql-master-1 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM sua_tabela;"
docker exec mysql-master-2 mysql -uroot -pteste123 -e "USE db_test; SELECT COUNT(*) FROM sua_tabela;"

# Reiniciar replicação
./setup-replication.sh
```

## ⚙️ Personalizar

### Mudar senha padrão

Editar `.env`:
```env
DB_ROOT_PASSWORD=sua_senha_nova
DB_PASSWORD=sua_senha_nova
```

Depois rodar:
```bash
docker-compose down -v
docker-compose up -d
./setup-replication.sh
```

### Aumentar retenção de logs

Editar `docker/mysql/my-simple.cnf` e `docker/mysql/my-simple-2.cnf`:
```ini
[mysqld]
# Aumentar de 7 para 30 dias
expire_logs_days = 30
```

Depois rodar:
```bash
docker-compose restart
```

## 📞 Suporte

Para mais informações, veja:
- `README.md` - Documentação completa
- `RELATORIO_TESTES_RESILIENCIA.md` - Análise de testes
- `NETWORK_ACCESS.md` - Acesso aos serviços

---

**Última atualização**: 31 de outubro de 2025
