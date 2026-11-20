# Image Refresh CronJob

The CronJob restarts Deployments in `default`, `media`, and `beszel`, plus DaemonSets in `beszel` (including the Beszel agent). It waits up to five minutes for each rollout. A restart can pull a newer image when its pull policy allows it; a restart alone does not mean an image changed.

The history contains one UTC-timestamped line per workload when any container's observed image changes, for example:

```text
2026-11-20T09:59:04Z media/deployment/sabnzbd container image changed
```

The line indicates an observed change in the configured image or runtime image IDs, not proof that a new image was pulled. Unchanged workloads produce no lines. Comparisons requiring missing pods or image IDs are reported to Job stderr, not as changes. The history does not record init containers or updates performed outside this Job. Existing log entries are not rewritten.

On `apollo`, ensure the container's UID 1001 can traverse and write to `/home/quinten`, and can write to any existing log file. Rotation also requires permission to rename and remove files in that directory. The whole directory is mounted writable in the container, so grant these permissions only if that access is acceptable.

Verify that the node's `kubernetes.io/hostname` label is `apollo`; the CronJob is pinned to that node because hostPath storage is node-local. Apply the resources with:

```bash
kubectl apply -k infrastructure/image-refresh
```

Read `/home/quinten/image-refresh.log` directly on the host. The file is created when the Job starts, even if no images change, and rotates at 5 MiB, retaining five older files (`.1` is the newest). Changed lines are also written to stdout. Back up the log files separately if needed. Logs from the previous `/home/quinten/image-refresh-logs` directory are not moved automatically; preserve or migrate them separately.

The old `image-refresh-logs` PVC remains managed but is no longer mounted, and its history is not moved automatically. Preserve or migrate that history separately before removing the PVC from the configuration and deleting it.

The pod opts in to mounting its service account token so `kubectl` can authenticate to the Kubernetes API. Changes to the CronJob apply to new Jobs only. Check Job logs and status for errors and unavailable comparisons; a failed restart or rollout fails the Job. The CronJob retains the most recent successful Job and two failed Jobs. Avoid overlapping manual and scheduled Jobs: the CronJob concurrency policy does not prevent manually created Jobs from running at the same time.

