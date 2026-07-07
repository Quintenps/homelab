# Homelab

This repository stores my homelab configuration for my k3s Kubernetes environment.

My homeserver is **apollo** and I use this repo to keep cluster and app settings versioned, reproducible, and easy to expand over time.

## Current services

- Sabnzbd
- Sonarr
- Radarr
- Plex

## Suggested structure

- `clusters/apollo/` - cluster-specific k3s settings for apollo
- `infrastructure/` - shared cluster components (networking, storage, observability, etc.)
- `apps/servarr/` - media stack app configs
  - `sabnzbd/`
  - `sonarr/`
  - `radarr/`
  - `plex/`
- `apps/future/` - placeholder for additional self-hosted services
