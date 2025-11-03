# MYSQL Configurações

O usuário dentro do seu container precisa de permissão para leitura dos arquivos de configuração do mysql como my.cnf, sem essa permissão o seu container não irá importar a configuração do arquivo de forma automática. Um script alternativo será adicionado em breve para corrigir.

## Correção manual

Adicionando permissões para o arquivo fora do container, dentro do diretório de prod no server selecionado.

```
#server-1
sudo chmod 644 ./mysql/my-config-1.cnf

#server-2
sudo chmod 644 ./mysql/my-config-2.cnf

```

## Container

Após a adição de permissão será necessário a reinicialização do container: 

```
#Comando para parar a execução dos containers e voltar novamente. 
docker-compose down && docker-compose up -d
```