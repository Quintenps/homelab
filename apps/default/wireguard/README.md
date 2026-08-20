# Wireguard VPN

## Configuration

This deployment uses automatic peer generation via LinuxServer's WireGuard image environment variables. The configuration and keys are automatically generated and stored in a PersistentVolumeClaim.

## Environment Variables

- `PEERS`: Number of peers to generate (default: 1)
- `PEERDNS`: DNS for peers (default: auto - uses the pod's DNS)
- `SERVERPORT`: WireGuard listen port (default: 51820)
- `ALLOWEDIPS`: CIDR notation of allowed IPs (default: 0.0.0.0/0)

## Deploy

```bash
kubectl apply -k .
```

## Access Generated Configurations

After deployment, peer configurations are automatically generated in the PVC:

```bash
kubectl exec -n wireguard deployment/wireguard -- cat /config/peer1/peer1.conf
```
