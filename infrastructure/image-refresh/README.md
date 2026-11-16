# Image Refresh CronJob

The CronJob restarts Deployments in `default`, `media`, and `beszel`, plus DaemonSets in `beszel` (including the Beszel agent). It waits up to five minutes for each rollout. A restart can pull a newer image when its pull policy allows it; a restart alone does not mean an image changed.

The history records UTC timestamps, rollout results, and the configured image and observed runtime image IDs of each workload's containers before and after the rollout. A comparison is unavailable when no active pods or image IDs are observed. It does not record init containers or updates performed outside this Job.

Logs are also written to stdout and persisted in the `image-refresh-logs` PVC. The file `/logs/image-refresh.log` rotates at 5 MiB, retaining five older files (`.1` is the newest). The cluster's default local-path storage is node-local and its data is deleted if the PVC is deleted; back it up separately if needed.

Apply the resources with:

```bash
kubectl apply -k infrastructure/image-refresh
```

The pod opts in to mounting its service account token so `kubectl` can authenticate to the Kubernetes API. Changes to the CronJob apply to new Jobs only. Check Job logs and status to verify success; a failed restart or rollout fails the Job.

To inspect the persistent history, start a temporary read-only log reader:

```bash
kubectl run image-refresh-log-reader -n default --image=bitnami/kubectl:latest \
  --restart=Never --rm -it \
  --overrides='{"spec":{"automountServiceAccountToken":false,"securityContext":{"fsGroup":1001},"containers":[{"name":"image-refresh-log-reader","image":"bitnami/kubectl:latest","stdin":true,"tty":true,"command":["/bin/sh"],"volumeMounts":[{"name":"logs","mountPath":"/logs","readOnly":true}]}],"volumes":[{"name":"logs","persistentVolumeClaim":{"claimName":"image-refresh-logs"}}]}}'
```

In the reader, use `ls -l /logs` and `cat /logs/image-refresh.log` (or an older numbered file), then `exit`. Avoid overlapping manual and scheduled Jobs: the CronJob concurrency policy does not prevent manually created Jobs from running at the same time.
