# Resource Quotas and Limits Configuration

## Overview

- **Hardware**: Intel Core i5-7500T (4 cores, 8GB memory)
- **System Reserve**: ~10% (0.4 cores, 800MB) for kubelet, system pods, and overhead
- **Allocatable**: ~3.6 cores, 7.2GB

### Namespace Allocation

| Namespace | CPU | Memory | Purpose |
|-----------|-----|--------|---------|
| default | 1.2 cores (30%) | 2.4GB (30%) | Homepage, Wireguard |
| media | 2.4 cores (60%) | 4.8GB (60%) | Plex, qBittorrent, Sonarr, Radarr, SABnzbd |

