## Run
docker compose down && docker compose up --remove-orphans -d


## TODO:
[] Add continue.dev assistant (https://docs.openwebui.com/tutorials/integrations/continue-dev)
[] Add https://github.com/nocodb/nocodb
[] Setup Domains

## Requirements

#### Searxng

- Requires adding json as enabled format in Searxng/settings.yaml
- In openwebui, settings is: `http://{IP}:7777/search?disabled_engines=&enabled_engines=bing__general&q=<query>`

### Reference

- [Docker Compose #1](https://github.com/coleam00/local-ai-packaged/blob/main/docker-compose.yml)
- [Docker Compose #1](https://github.com/NunoTek/Local-AI-Server/blob/main/docker-compose.yml)
- [Redis Reference](https://docs.openwebui.com/tutorials/integrations/redis)

## Issues Occured

### AnythingLLM
Couldn't use the mounted folder

```bash
chmod -R 777 /mnt/nas/DockerServices/anythingllm
```

### n8n No Database
If n8n fails to start due to no database, try recreating the container after ensuring Postgres is running.

```bash
docker exec -it vector-admin-postgres psql -U vectoradmin -p 5433 -c "CREATE DATABASE n8n;"
docker compose restart n8n