# 🐳 Dockerfile para Setup de Replicação

## 📋 Visão Geral

Criei um Dockerfile que automatiza a execução do `setup-replication.sh` logo após os containers MySQL estarem prontos (saudáveis). Isso elimina a necessidade de executar o script manualmente.

## 📁 Arquivos Criados

### 1. **Dockerfiles**
- `dev/Dockerfile` - Para ambiente de desenvolvimento
- `prod/server-1/Dockerfile` - Para Master 1 de produção
- `prod/server-2/Dockerfile` - Para Master 2 de produção

### 2. **Docker Compose Atualizados**
- `dev/docker-compose.yml` - Adicionado serviço `setup-replication`
- `prod/server-1/docker-compose.yml` - Adicionado serviço `setup-replication`
- `prod/server-2/docker-compose.yml` - Adicionado serviço `setup-replication`

## 🚀 Como Usar

### Desenvolvimento (dev/)

```bash
cd dev/

# Build e iniciar todos os containers (incluindo setup automático)
docker-compose up -d

# Verificar logs do setup-replication
docker-compose logs setup-replication
```

### Produção - Server 1

```bash
cd prod/server-1/

# Definir IP do Master 2 (opcional, padrão é 'mysql-master-2')
export MASTER2_IP=192.168.1.20

# Build e iniciar
docker-compose up -d

# Verificar logs
docker-compose logs setup-replication
```

### Produção - Server 2

```bash
cd prod/server-2/

# Definir IP do Master 1 (opcional, padrão é 'mysql-master-1')
export MASTER1_IP=192.168.1.10

# Build e iniciar
docker-compose up -d

# Verificar logs
docker-compose logs setup-replication
```

## 🔍 Como Funciona

### Ordem de Execução

1. **Containers MySQL iniciam** com `healthcheck`
2. **Quando MySQL está pronto**, o serviço `setup-replication` inicia
3. **Dockerfile constrói a imagem** com:
   - Base `bash:latest`
   - Instala `mysql-client`
   - Copia o script `setup-replication.sh`
4. **Script executa automaticamente**, configurando a replicação

### Fluxo de Dependências

```yaml
mysql-master-1 (healthy)
    ↓
setup-replication (depends_on: mysql-master-1 healthy)
    ↓
phpmyadmin (depende do MySQL)
```

## ⚙️ Dockerfile Detalhado

```dockerfile
# Imagem base com bash
FROM bash:latest

# Instala cliente MySQL para comunicar com containers
RUN apk add --no-cache mysql-client

# Copia o script de setup
COPY ./exec/setup-replication.sh /setup-replication.sh

# Permite execução
RUN chmod +x /setup-replication.sh

# Variável de ambiente com IP do outro master
ENV MASTER2_IP=${MASTER2_IP:-mysql-master-2}

# Executa o script com IP como argumento
ENTRYPOINT ["/setup-replication.sh"]
CMD ["${MASTER2_IP}"]
```

## 📊 Variáveis de Ambiente

### DEV (dev/docker-compose.yml)
```env
MASTER2_IP=mysql-master-2  # Use o nome do container
```

### PROD Server-1 (prod/server-1/docker-compose.yml)
```env
MASTER2_IP=192.168.1.20    # IP do servidor Master 2 (produção)
```

### PROD Server-2 (prod/server-2/docker-compose.yml)
```env
MASTER1_IP=192.168.1.10    # IP do servidor Master 1 (produção)
```

## 🛑 Troubleshooting

### Erro: "CHANGE MASTER TO failed"

**Causa**: IPs incorretos ou containers não acessíveis

**Solução**:
```bash
# Verificar conectividade entre containers
docker exec mysql-master-1 ping mysql-master-2
docker exec mysql-master-1 mysql -u replicador -pteste123 -h mysql-master-2 -e "SELECT 1"

# Verificar logs do setup
docker-compose logs setup-replication
```

### Erro: "Could not connect to Master"

**Causa**: Master ainda não está pronto

**Solução**: 
- Aumentar `start_period` no healthcheck
- Aguardar mais tempo antes de executar setup

```yaml
healthcheck:
  start_period: 45s  # Aumentar de 30s para 45s
```

### Setup rodou mas Docker volta ao status "running"

**Normal!** O container `setup-replication` executa uma única vez e depois sai (status `exited`).

```bash
# Ver status
docker-compose ps

# Output esperado:
# setup-replication-master-1    Exited (0)
```

## ✅ Verificar Replicação

Após o setup rodar:

```bash
# Verificar logs
docker-compose logs setup-replication | grep -E "(✅|🎉|⚠️)"

# Conectar ao MySQL
docker exec -it mysql-master-1 mysql -uroot -pteste123 -e "SHOW SLAVE STATUS\G"

# Esperado ver:
# Slave_IO_Running: Yes
# Slave_SQL_Running: Yes
```

## 🔄 Forçar Re-setup

Se precisar executar o setup novamente:

```bash
# Remover container de setup
docker-compose rm -f setup-replication

# Reconstruir e iniciar
docker-compose up -d setup-replication

# Ver logs
docker-compose logs -f setup-replication
```

## 📝 Diferenças entre DEV e PROD

| Aspecto | DEV | PROD |
|---------|-----|------|
| **Dockerfile** | `dev/Dockerfile` | `server-1/Dockerfile` + `server-2/Dockerfile` |
| **Nomes Containers** | `setup-replication-dev` | `setup-replication-master-1/2` |
| **IPs** | Nomes de containers (Docker DNS) | IPs reais da rede (ex: 192.168.1.10) |
| **Argumentos** | `mysql-master-2` | `192.168.1.20` |

## 🎯 Próximas Otimizações (Opcional)

1. **Health check customizado**: Verifica se replicação está ativa
2. **Retry logic**: Tenta setup múltiplas vezes se falhar
3. **Notificações**: Envia alerta se setup falhar
4. **Logging centralizado**: Salva logs em arquivo

---

**Status**: ✅ Implantado  
**Testado em**: dev/ e prod/server-1  
**Última atualização**: 1 de novembro de 2025
