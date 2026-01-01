# Homelab

## Overview

This repository documents homelab setup, configurations, and Docker Compose files. The homelab runs on Proxmox VE with TrueNAS SCALE as a VM, providing storage and containerized services using Docker managed via Portainer.

## Commands:

- Docker Compose: `docker compose down && docker image prune -a -f && docker compose build && docker compose up -d`
- **Updating Container**: `docker compose up -d --pull always --no-deps --force-recreate prowlarr`

- **Schedule Restart Script**: `./scripts/schedule_restart_compose.sh <service-name> <delay-in-minutes>`
  - View Restart Log: `cat ./logs/time_script.log`
  - Example: `/mnt/nas/DockerServices/_homelab/scripts/schedule_restart_compose.sh schedule /mnt/nas/DockerServices/_homelab/admin/network_proxy "tomorrow 07:00"`

## Wishlist

- Try Supabase: https://github.com/supabase-community/supabase-traefik/blob/main/docker-compose.example.yml
