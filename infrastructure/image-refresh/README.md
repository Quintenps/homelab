# Image Refresh CronJob

The CronJob restarts Deployments in `default`, `media`, and `beszel`, plus DaemonSets in `beszel` (including the Beszel agent). It waits up to five minutes for each rollout. A restart can pull a newer image when its pull policy allows it; a restart alone does not mean an image changed.

The history contains one UTC-timestamped line per container whose observed image changed, including the workload and the configured image and runtime image IDs before and after the rollout. Multiple IDs can appear when replicas run different images. Unchanged containers produce no lines. Comparisons requiring missing pods or image IDs are reported to Job stderr, not as changes. The history does not record init containers or updates performed outside this Job.

On `apollo`, prepare the host directory before deploying. The container runs as UID 1001 and needs permission to write and rotate files in this directory:

```bash
sudo install -d -o 1001 -g 1001 -m 755 /home/quinten/image-refresh-logs
```

Verify that the node's `kubernetes.io/hostname` label is `apollo`; the CronJob is pinned to that node because hostPath storage is node-local. Apply the resources with:

```bash
kubectl apply -k infrastructure/image-refresh
```

Read `/home/quinten/image-refresh-logs/image-refresh.log` directly on the host. The file is created on the first observed change and rotates at 5 MiB, retaining five older files (`.1` is the newest). Changed lines are also written to stdout. Back up the directory separately if needed.

The old `image-refresh-logs` PVC remains managed but is no longer mounted, and its history is not moved automatically. Preserve or migrate that history separately before removing the PVC from the configuration and deleting it.

The pod opts in to mounting its service account token so `kubectl` can authenticate to the Kubernetes API. Changes to the CronJob apply to new Jobs only. Check Job logs and status for errors and unavailable comparisons; a failed restart or rollout fails the Job. The CronJob retains the most recent successful Job and two failed Jobs. Avoid overlapping manual and scheduled Jobs: the CronJob concurrency policy does not prevent manually created Jobs from running at the same time.

