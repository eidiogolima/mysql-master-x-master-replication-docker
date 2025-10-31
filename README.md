# 🐳 MySQL Master x Master Replication com Docker

Este projeto configura uma replicação MySQL Master x Master utilizando Docker Compose, com phpMyAdmin para administração.

## 🚀 Como usar

### 1. Iniciar os containers
```bash
docker-compose up -d
```

### 2. Configurar replicação automaticamente
```bash
./setup-replication.sh
```

### 3. Verificar status da replicação
```bash
./check-replication.sh
```

## 🔧 Configuração

### Serviços disponíveis:
- **mysql-master-1**: MySQL 8.0 (apenas rede interna)
- **mysql-master-2**: MySQL 8.0 (apenas rede interna)
- **phpmyadmin**: Interface web (porta 8085 - única porta exposta)

### Credenciais padrão:
- **Root password**: teste123
- **Usuário de replicação**: replicador
- **Senha de replicação**: teste123

## 🌐 Acesso

- **phpMyAdmin**: http://localhost:8085 (✅ Único acesso externo)
- **MySQL Masters**: Apenas via rede interna do Docker (🔒 Isolados)

> 📝 **Nota**: Os serviços MySQL não estão expostos externamente, evitando conflitos com outros projetos MySQL na porta 3306.

### 🔧 Acesso interno aos MySQL (se necessário):
```bash
# Conectar ao Master 1
docker exec -it mysql-master-1 mysql -uroot -pteste123

# Conectar ao Master 2
docker exec -it mysql-master-2 mysql -uroot -pteste123
```

### 🔗 Conectar outros projetos à mesma rede:
Se precisar que outros containers acessem estes MySQL, adicione ao docker-compose.yml do outro projeto:
```yaml
networks:
  default:
    external: true
    name: phpmyadmin_mysql_master_mysql-network
```

## 📊 Monitoramento

### Verificar logs dos containers:
```bash
docker-compose logs mysql-master-1
docker-compose logs mysql-master-2
```

### Status detalhado da replicação:
```bash
# Master 1
docker exec mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G"

# Master 2
docker exec mysql-master-2 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G"
```

## 🛠️ Características da configuração

### Resistência a falhas:
- ✅ Detecção automática de falhas de rede
- ✅ Recuperação automática de logs corrompidos
- ✅ Tratamento de conflitos de replicação
- ✅ GTID habilitado para rastreamento global
- ✅ Checksums para integridade de dados
- ✅ Timeouts otimizados para alta disponibilidade
- ✅ **Testado**: Resiliência comprovada em cenários de queda (veja `RELATORIO_TESTES_RESILIENCIA.md`)

### Configurações de performance:
- ✅ Buffers otimizados para replicação
- ✅ InnoDB configurado para durabilidade
- ✅ Auto-increment configurado para evitar conflitos
- ✅ Logs detalhados para troubleshooting

## 🧪 Testes de Resiliência

Este projeto inclui testes automatizados para validar o comportamento do sistema em cenários de falha:

- **Teste 1**: Queda de Master 2 por 1 minuto
- **Teste 2**: Queda simultânea de ambos os masters por 1 minuto

### Executar testes:
```bash
./test-failover-resilience.sh
```

**Resultado**: ✅ Todos os testes passaram com sucesso - Zero perda de dados

Veja relatório completo: `RELATORIO_TESTES_RESILIENCIA.md`

## 🚨 Troubleshooting

### Replication lag alto:
1. Verificar recursos do sistema
2. Analisar slow query log
3. Otimizar consultas problemáticas

### Erros de replicação:
1. Executar: `./check-replication.sh`
2. Verificar logs: `docker-compose logs`
3. Reiniciar replicação se necessário:
   ```bash
   docker exec mysql-master-1 mysql -uroot -pteste123 -e "STOP SLAVE; START SLAVE;"
   ```

### Reset completo:
```bash
docker-compose down -v
docker-compose up -d
./setup-replication.sh
```

## 📁 Estrutura do projeto

```
.
├── docker-compose.yml          # Definição dos serviços
├── .env                        # Variáveis de ambiente
├── setup-replication.sh       # Script de configuração automática
├── check-replication.sh       # Script de monitoramento
├── docker/
│   └── mysql/
│       ├── my.cnf             # Configuração MySQL Master 1
│       └── my-master-2.cnf    # Configuração MySQL Master 2
├── mysql-master-1-data/       # Dados persistentes Master 1
└── mysql-master-2-data/       # Dados persistentes Master 2
```

## ⚠️ Importante

- Esta configuração é para desenvolvimento/teste
- Para produção, ajuste as senhas e configurações de segurança
- Faça backups regulares dos dados
- Monitore o lag de replicação constantemente