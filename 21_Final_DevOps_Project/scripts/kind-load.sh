#!/usr/bin/env bash
# kind load docker-image fails on Docker Desktop for multi-platform images
# ("content digest ... not found"), so import a single-platform export instead.
set -euo pipefail
img="$1"
for node in $(kind get nodes --name devops-hw); do
  docker save --platform linux/arm64 "$img" | docker exec -i "$node" ctr --namespace=k8s.io images import --snapshotter=overlayfs - >/dev/null
  echo "loaded $img into $node"
done
