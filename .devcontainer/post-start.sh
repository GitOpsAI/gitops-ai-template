#!/usr/bin/env bash
# Runs on every codespace start: restores the SOPS age key and brings stopped k3d clusters back.
set -euo pipefail

key_dir="${SOPS_AGE_KEY_DIR:-$HOME/.sops}"
key_file="${key_dir}/age.agekey"
if [ -n "${SOPS_AGE_KEY:-}" ] && [ ! -s "$key_file" ]; then
  (
    umask 077
    mkdir -p "$key_dir"
    printf '%s\n' "$SOPS_AGE_KEY" > "$key_file"
  )
  echo "post-start: restored SOPS age key to ${key_file}"
fi

command -v k3d > /dev/null || exit 0

# docker-in-docker starts dockerd asynchronously.
for _ in $(seq 1 30); do
  docker info > /dev/null 2>&1 && break
  sleep 2
done
if ! docker info > /dev/null 2>&1; then
  echo "post-start: Docker is not ready; start clusters later with 'k3d cluster start --all'" >&2
  exit 0
fi

mkdir -p "$HOME/.kube"
chmod 700 "$HOME/.kube"
for cluster in $(k3d cluster list --no-headers 2> /dev/null | awk '{print $1}'); do
  if ! k3d cluster start "$cluster" --wait --timeout 300s; then
    echo "post-start: k3d cluster '${cluster}' did not start; check 'docker ps -a'" >&2
    continue
  fi
  (
    umask 077
    k3d kubeconfig get "$cluster" > "$HOME/.kube/k3d-${cluster}"
  )
  k3d kubeconfig merge "$cluster" --kubeconfig-merge-default --kubeconfig-switch-context > /dev/null
  echo "post-start: k3d cluster '${cluster}' is running"
done
