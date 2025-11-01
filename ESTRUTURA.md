# 📁 Estrutura do Projeto

## Diretório Raiz

```
phpmyadmin_mysql_master/
│
├── README.md                      # 📖 Guia geral do projeto
├── screenshot.png                 # 📷 Screenshot da aplicação
│
├── dev/                           # 🔧 Ambiente de DESENVOLVIMENTO
│   │                               # (single docker-compose com 2 masters)
│   ├── docker-compose.yml         # Configuração Docker
│   ├── docker/
│   │   └── mysql/
│   │       ├── my-simple.cnf      # Config Master 1 (dev)
│   │       └── my-simple-2.cnf    # Config Master 2 (dev)
│   │
│   ├── setup-replication.sh       # ⚙️ Setup de replicação
│   ├── check-replication.sh       # 📊 Monitorar replicação
│   ├── test-failover-resilience.sh # 🧪 Testes de resiliência
│   │
│   ├── QUICK_START.md             # 🚀 Início rápido (dev)
│   ├── README.md                  # 📖 Documentação (dev)
│   └── .gitignore
│
└── prod/                          # 🏢 Ambiente de PRODUÇÃO
    │                               # (servidores separados)
    │
    ├── SETUP_PRODUCAO.md          # 🚀 Guia de deploy (produção)
    ├── check-replication.sh       # 📊 Monitorar replicação
    │
    ├── server-1/                  # 🖥️ Master 1 (192.168.1.10)
    │   ├── docker-compose.yml     # Configuração Docker
    │   ├── .env                   # Variáveis de ambiente
    │   ├── README.md              # 📖 Documentação server-1
    │   │
    │   ├── myql/                  # 📄 Configurações MySQL
    │   │   └── my-config-1.cnf    # Config Master 1
    │   │
    │   └── exec/                  # 🔧 Scripts executáveis
    │       └── setup-replication.sh
    │
    └── server-2/                  # 🖥️ Master 2 (192.168.1.20)
        ├── docker-compose.yml     # Configuração Docker
        ├── .env                   # Variáveis de ambiente
        ├── README.md              # 📖 Documentação server-2
        │
        ├── mysql/                 # 📄 Configurações MySQL
        │   └── my-config-2.cnf    # Config Master 2
        │
        └── exec/                  # 🔧 Scripts executáveis
            └── setup-replication.sh
```

## 📂 Descrição de Cada Diretório

### `/dev` - Ambiente de Desenvolvimento

**Propósito**: Testar e validar a replicação localmente em uma única máquina.

**Uso**:
```bash
cd dev/
docker-compose up -d
./setup-replication.sh mysql-master-2
```

**Quando usar**:
- Testes iniciais
- Validação de configurações
- Simulações de falha
- Desenvolvimento

**Características**:
- Dois containers MySQL na mesma máquina
- Rede Docker interna
- phpMyAdmin na porta 8085
- Scripts para testes automáticos

---

### `/prod/server-1` - Master 1 de Produção

**Propósito**: Primeiro servidor MySQL de produção.

**IP**: 192.168.1.10 (exemplo)  
**Porto MySQL**: 3306  
**phpMyAdmin**: http://192.168.1.10:8085

**Estrutura**:
```
server-1/
├── docker-compose.yml      # Define mysql-master-1 + phpmyadmin
├── .env                    # Senhas e variáveis
├── README.md               # Guia específico de server-1
├── myql/                   # 📝 Nota: typo "myql" ao invés de "mysql"
│   └── my-config-1.cnf     # Configuração MySQL
└── exec/
    └── setup-replication.sh # Configura replicação com Master 2
```

**Configuração GTID**:
- `server-id = 1`
- `auto-increment-offset = 1` (números ímpares: 1,3,5...)
- `MASTER_HOST = 192.168.1.20`

---

### `/prod/server-2` - Master 2 de Produção

**Propósito**: Segundo servidor MySQL de produção.

**IP**: 192.168.1.20 (exemplo)  
**Porto MySQL**: 3306  
**phpMyAdmin**: http://192.168.1.20:8085

**Estrutura**:
```
server-2/
├── docker-compose.yml               # Define mysql-master-2 + phpmyadmin
├── .env                             # Senhas e variáveis (MESMAS de server-1)
├── README.md                        # Guia específico de server-2
├── mysql/                           # Diretório correto (não "myql")
│   └── my-config-2.cnf              # Configuração MySQL
└── exec/
    └── setup-replication.sh # Configura replicação com Master 1
```

**Configuração GTID**:
- `server-id = 2`
- `auto-increment-offset = 2` (números pares: 2,4,6...)
- `MASTER_HOST = 192.168.1.10`

---

## 🔗 Fluxo de Replicação

```
┌─────────────────────────┐
│   Master 1              │
│   192.168.1.10:3306     │
│   server-id = 1         │
└──────────────┬──────────┘
               │
        ↙ GTID Replication ↗
               │
┌──────────────┴──────────┐
│   Master 2              │
│   192.168.1.20:3306     │
│   server-id = 2         │
└─────────────────────────┘

Bidirecional:
  Master 1 → Master 2: CHANGE MASTER TO MASTER_HOST='192.168.1.20'
  Master 2 → Master 1: CHANGE MASTER TO MASTER_HOST='192.168.1.10'
```

---

## 📊 Arquivos de Configuração

### my-config-1.cnf (Master 1)

```ini
[mysqld]
server-id = 1                           # Identificação única
bind-address = 0.0.0.0                  # Aceita conexões externas
log-bin = mysql-bin                     # Ativa binary logging
log-slave-updates = 1                   # Propaga mudanças do slave
gtid_mode = ON                          # GTID-based replication
enforce_gtid_consistency = ON           # Força consistência
auto-increment-increment = 2            # Incremento de 2
auto-increment-offset = 1               # Começa com 1 (números ímpares)
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

### my-config-2.cnf (Master 2)

```ini
[mysqld]
server-id = 2                           # ID diferente do Master 1!
bind-address = 0.0.0.0
log-bin = mysql-bin
log-slave-updates = 1
gtid_mode = ON
enforce_gtid_consistency = ON
auto-increment-increment = 2
auto-increment-offset = 2               # Começa com 2 (números pares)
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
```

**Diferença crítica**: `server-id` e `auto-increment-offset`

---

## 🔧 Scripts Executáveis

### setup-replication.sh (Master 1)

**Localização**: `prod/server-1/exec/`

**Função**: Configura Master 1 para replicar do Master 2

**Uso**:
```bash
./setup-replication.sh 192.168.1.20
```

**O que faz**:
1. Cria usuário `replicador` no Master 1
2. Executa `CHANGE MASTER TO` apontando para 192.168.1.20
3. Inicia replicação com `START SLAVE`
4. Verifica status

---

### setup-replication.sh (Master 2)

**Localização**: `prod/server-2/exec/`

**Função**: Configura Master 2 para replicar do Master 1

**Uso**:
```bash
./setup-replication.sh 192.168.1.10
```

**O que faz**:
1. Cria usuário `replicador` no Master 2
2. Executa `CHANGE MASTER TO` apontando para 192.168.1.10
3. Inicia replicação com `START SLAVE`
4. Verifica status

---

### check-replication.sh

**Localização**: `prod/`

**Função**: Verifica status de replicação em ambos os servers

**Uso**:
```bash
        # Ambos
../check-replication.sh master1     # Apenas Master 1
../check-replication.sh master2     # Apenas Master 2
```

---

## 🐳 Docker Compose Files

### docker-compose.yml (server-1)

Define:
- `mysql-master-1`: Container MySQL
- `phpmyadmin`: Container web admin
- `mysql-network`: Rede Docker interna
- Volume `mysql-master-1-data`: Persistência

### docker-compose.yml (server-2)

Define:
- `mysql-master-2`: Container MySQL
- `phpmyadmin`: Container web admin
- `mysql-network`: Rede Docker interna
- Volume `mysql-master-2-data`: Persistência

**Nota**: Cada servidor tem seu próprio phpMyAdmin na porta 8085 (ambos na mesma máquina não funciona - porta duplicada)

---

## 📋 .env Files

### Ambos os servidores

```env
DB_ROOT_PASSWORD=SuaSenhaForte123!
DB_PASSWORD=SenhaReplicador456!
```

**⚠️ CRÍTICO**: Deve ser IDÊNTICO em ambos os servidores!

---

## 🗂️ Convenção de Nomes

| Item | Convenção | Exemplo |
|------|-----------|---------|
| Container MySQL 1 | `mysql-master-1` | ✓ |
| Container MySQL 2 | `mysql-master-2` | ✓ |
| Volume 1 | `mysql-master-1-data` | ✓ |
| Volume 2 | `mysql-master-2-data` | ✓ |
| Config 1 | `my-config-1.cnf` | ✓ |
| Config 2 | `my-config-2.cnf` | ✓ |
| Usuário Replicação | `replicador` | ✓ |
| Senha Padrão | `teste123` | (mudar em prod!) |

---

## 🔐 Fluxo de Senhas

```
.env (server-1)
  ↓
  DB_ROOT_PASSWORD → MYSQL_ROOT_PASSWORD → root:teste123
  DB_PASSWORD → MYSQL_PASSWORD → replicador:teste123
  ↓
docker-compose.yml
  ↓
setup-replication.sh
  ├─ CREATE USER 'replicador'@'%' IDENTIFIED BY 'teste123'
  └─ GRANT REPLICATION SLAVE ON *.*

setup-replication.sh
  ├─ CREATE USER 'replicador'@'%' IDENTIFIED BY 'teste123'
  └─ GRANT REPLICATION SLAVE ON *.*

CHANGE MASTER TO
    MASTER_HOST='192.168.1.20',
    MASTER_USER='replicador',
    MASTER_PASSWORD='teste123',    ← DEVE COINCIDIR
    MASTER_AUTO_POSITION=1;
```

---

## 📊 Checklist de Estrutura

- [ ] `/dev` tem docker-compose.yml
- [ ] `/dev/docker/mysql/` tem configurações
- [ ] `/dev` tem scripts (setup, check, test)
- [ ] `/prod/server-1` tem docker-compose.yml
- [ ] `/prod/server-1/myql/` tem my-config-1.cnf
- [ ] `/prod/server-1/exec/` tem setup-replication.sh
- [ ] `/prod/server-2` tem docker-compose.yml
- [ ] `/prod/server-2/mysql/` tem my-config-2.cnf
- [ ] `/prod/server-2/exec/` tem setup-replication.sh
- [ ] `/prod` tem check-replication.sh
- [ ] `.env` existe em ambos os servers
- [ ] README.md em raiz e em cada servidor

---

**Última atualização**: 31 de outubro de 2025
