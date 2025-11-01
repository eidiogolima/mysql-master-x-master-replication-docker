# 🔒 Acesso aos MySQL Internos

Os serviços MySQL agora estão configurados para funcionar apenas na rede interna do Docker, sem exposição de portas externas.

## 🌐 Acessos Disponíveis

### ✅ Acesso Externo (Permitido)
- **phpMyAdmin**: http://localhost:8085
  - Conecta automaticamente aos dois MySQL masters
  - Interface web completa para administração

### 🔒 Acesso Interno (Apenas entre containers)
- **mysql-master-1**: `mysql-master-1:3306`
- **mysql-master-2**: `mysql-master-2:3306`

## 🛠️ Como acessar MySQL via linha de comando (se necessário)

### 1. Conectar via container phpMyAdmin:
```bash
docker exec -it phpmyadmin bash
# Dentro do container, você pode usar mysql client se instalado
```

### 2. Conectar diretamente aos containers MySQL:
```bash
# Master 1
docker exec -it mysql-master-1 mysql -uroot -pteste123

# Master 2
docker exec -it mysql-master-2 mysql -uroot -pteste123
```

### 3. Para outros containers se conectarem:
Se você tiver outros projetos que precisam acessar estes MySQL, adicione-os à mesma rede:

```yaml
# No docker-compose.yml do outro projeto
networks:
  default:
    external: true
    name: phpmyadmin_mysql_master_mysql-network
```

## 📊 Monitoramento

Os scripts de monitoramento continuam funcionando normalmente:
```bash
./check-replication.sh
```

## 🔄 Configuração de Replicação

O script de setup foi atualizado para funcionar com a nova configuração interna:
```bash
./setup-replication.sh
```

## ⚡ Vantagens desta configuração

1. **Isolamento**: MySQL não interfere com outros projetos na porta 3306
2. **Segurança**: Banco de dados não exposto externamente
3. **Organização**: Apenas phpMyAdmin acessível via browser
4. **Performance**: Comunicação interna mais rápida entre containers
5. **Flexibilidade**: Outros containers podem se conectar à rede se necessário