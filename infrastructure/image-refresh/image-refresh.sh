#!/bin/sh
set -eu

log_file=/logs/image-refresh.log
max_log_bytes=5242880

log() {
  if [ -f "$log_file" ] && [ "$(wc -c < "$log_file")" -ge "$max_log_bytes" ]; then
    for n in 4 3 2 1; do
      if [ -f "$log_file.$n" ]; then
        mv "$log_file.$n" "$log_file.$((n + 1))"
      fi
    done
    mv "$log_file" "$log_file.1"
  fi
  printf '%s %s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$*" | tee -a "$log_file"
}

run_kubectl() {
  if output=$(kubectl "$@" 2>&1); then
    printf '%s\n' "$output"
  else
    log "ERROR: kubectl $* failed: $output" >&2
    return 1
  fi
}

snapshot() {
  namespace=$1
  kind=$2
  workload=$3
  uid=$(run_kubectl -n "$namespace" get "$kind" "$workload" -o jsonpath='{.metadata.uid}')
  if [ "$kind" = deployment ]; then
    replicasets=$(run_kubectl -n "$namespace" get replicasets -o json)
    owners=$(printf '%s\n' "$replicasets" | jq -c --arg uid "$uid" \
      '[.items[] | select(any(.metadata.ownerReferences[]?; .controller == true and .uid == $uid)) | .metadata.uid]')
  else
    owners=$(jq -cn --arg uid "$uid" '[$uid]')
  fi
  pods=$(run_kubectl -n "$namespace" get pods -o json)
  images=$(printf '%s\n' "$pods" | jq -r --argjson owners "$owners" '
    .items[]
    | select(.metadata.deletionTimestamp == null)
    | select(any(.metadata.ownerReferences[]?; .controller == true and (.uid as $owner | $owners | index($owner) != null)))
    | . as $pod
    | .spec.containers[]
    | . as $container
    | (($pod.status.containerStatuses // []) | map(select(.name == $container.name)) | first // {}) as $status
    | "\($container.name)\t\($container.image)\t\(if $status.imageID != null and $status.imageID != "" then $status.imageID else "unavailable" end)"
  ')
  printf '%s\n' "$images" | sort -u
}

refresh() {
  namespace=$1
  kind=$2
  names=$(run_kubectl -n "$namespace" get "$kind" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
  if [ -z "$names" ]; then
    log "No ${kind}s in namespace $namespace"
    return
  fi
  for workload in $names; do
    log "Refreshing $namespace/$kind/$workload"
    before=$(snapshot "$namespace" "$kind" "$workload")
    log "Before $namespace/$kind/$workload (container, image, image ID): ${before:-unavailable}"
    result=$(run_kubectl -n "$namespace" rollout restart "$kind/$workload")
    log "$result"
    result=$(run_kubectl -n "$namespace" rollout status "$kind/$workload" --timeout=5m)
    log "$result"
    after=$(snapshot "$namespace" "$kind" "$workload")
    log "After $namespace/$kind/$workload (container, image, image ID): ${after:-unavailable}"
    if [ -z "$before" ] || [ -z "$after" ] ||
      printf '%s\n%s\n' "$before" "$after" | awk -F '\t' '$3 == "unavailable" {found=1} END {exit !found}'; then
      log "Image comparison unavailable for $namespace/$kind/$workload"
    elif [ "$before" = "$after" ]; then
      log "Observed images unchanged for $namespace/$kind/$workload"
    else
      log "Observed images changed for $namespace/$kind/$workload"
    fi
  done
}

trap 'status=$?; if [ "$status" -ne 0 ]; then log "Image refresh failed (exit $status)" || echo "Unable to write failure to image refresh log" >&2; fi' EXIT
log "Image refresh started"
for namespace in default media beszel; do
  refresh "$namespace" deployment
done
refresh beszel daemonset
log "Image refresh completed"
