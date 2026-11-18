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
  line="$(date -u '+%Y-%m-%dT%H:%M:%SZ') $*"
  printf '%s\n' "$line" >> "$log_file"
  printf '%s\n' "$line"
}

run_kubectl() {
  if output=$(kubectl "$@" 2>&1); then
    printf '%s\n' "$output"
  else
    printf 'ERROR: kubectl %s failed: %s\n' "$*" "$output" >&2
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
    return
  fi
  for workload in $names; do
    before=$(snapshot "$namespace" "$kind" "$workload")
    run_kubectl -n "$namespace" rollout restart "$kind/$workload" >/dev/null
    run_kubectl -n "$namespace" rollout status "$kind/$workload" --timeout=5m >/dev/null
    after=$(snapshot "$namespace" "$kind" "$workload")
    comparisons=$(jq -rn --arg before "$before" --arg after "$after" '
      def entries:
        split("\n") | map(select(length > 0) | split("\t") |
          {container: .[0], image: .[1], imageID: .[2]});
      ($before | entries) as $before
      | ($after | entries) as $after
      | ([$before[], $after[]] | map(.container) | unique)[] as $container
      | [$before[] | select(.container == $container) | {image, imageID}] as $old
      | [$after[] | select(.container == $container) | {image, imageID}] as $new
      | if ($old | length) == 0 or ($new | length) == 0 or
           any($old[], $new[]; .imageID == "unavailable") then
          "unavailable \($container)"
        elif $old != $new then
          "changed \({container: $container, before: $old, after: $new} | tojson)"
        else empty end
    ')
    if [ -z "$before" ] || [ -z "$after" ]; then
      printf 'WARNING: Image comparison unavailable for %s/%s/%s: no active container images observed\n' "$namespace" "$kind" "$workload" >&2
    fi
    if [ -n "$comparisons" ]; then
      while IFS= read -r comparison; do
        case "$comparison" in
          "changed "*) log "$namespace/$kind/$workload ${comparison#changed }" ;;
          "unavailable "*) printf 'WARNING: Image comparison unavailable for %s/%s/%s container %s\n' "$namespace" "$kind" "$workload" "${comparison#unavailable }" >&2 ;;
        esac
      done <<EOF
$comparisons
EOF
    fi
  done
}

trap 'status=$?; if [ "$status" -ne 0 ]; then printf "Image refresh failed (exit %s)\n" "$status" >&2; fi' EXIT
for namespace in default media beszel; do
  refresh "$namespace" deployment
done
refresh beszel daemonset
