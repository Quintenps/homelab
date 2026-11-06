# Beszel

The Hub is included in `apps`. Open it at `http://<beszel-load-balancer-ip>:8090` and create an account. Add the `apollo` system with host `beszel-agent.beszel.svc.cluster.local` and port `45876`, then copy its `KEY` and `TOKEN`.

Create a Secret from the `KEY` and `TOKEN` shown by Beszel. Do not commit these values:

```bash
kubectl create secret generic beszel-agent-auth -n beszel \
  --from-literal=KEY='<key>' \
  --from-literal=TOKEN='<token>'
```

Then deploy the Agent:

```bash
kubectl apply -k apps/beszel/agent
```

The Agent uses host networking and connects to the Hub over the cluster Service. K3s uses containerd, so Beszel reports host metrics but not containerd or per-pod statistics.
