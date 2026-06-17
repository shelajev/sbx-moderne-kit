#!/usr/bin/env bash
set -euo pipefail

namespace="${DOCKERHUB_NAMESPACE:-${DOCKER_NAMESPACE:-}}"
if [ -z "$namespace" ]; then
  echo "DOCKERHUB_NAMESPACE or DOCKER_NAMESPACE must be set" >&2
  exit 1
fi

stage="$(mktemp -d /tmp/moderne-kit-push.XXXXXX)"

cleanup() {
  rm -rf "$stage"
}
trap cleanup EXIT

rsync -a \
  --exclude '.git' \
  --exclude '.github' \
  --exclude '.DS_Store' \
  --exclude '.env' \
  --exclude '.sbx' \
  --exclude '*.tar' \
  --exclude '*.zip' \
  --exclude 'scripts' \
  --exclude 'tmp' \
  --exclude '.tmp' \
  ./ "$stage/moderne/"

sbx kit validate "$stage/moderne"
sbx kit push "$stage/moderne" "docker.io/$namespace/sbx-moderne-kit:latest"
