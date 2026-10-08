#!/usr/bin/env bash
# Runs the same stages as ci/pragya-library-ci.yml on my laptop:
#   test -> security -> build -> image scan gate -> load into kind
# Usage: scripts/ci-local.sh <version>     e.g. scripts/ci-local.sh 1.0.0
set -euo pipefail
VERSION="${1:?usage: ci-local.sh <version>}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/application"

step() { printf '\n==> %s\n' "$*"; }

step "1/6 backend tests"
( cd "$APP/backend" && python -m pytest -q -p no:cacheprovider -W ignore::DeprecationWarning )

step "2/6 frontend build"
( cd "$APP/frontend" && npm ci --no-audit --no-fund --silent && npm run build --silent )

step "3/6 secret scan (gitleaks, project folder only)"
gitleaks dir "$ROOT" --no-banner --no-color --redact

step "4/6 build images"
docker build -q -t "pragya-library-backend:$VERSION" "$APP/backend"
docker build -q -t "pragya-library-frontend:$VERSION" "$APP/frontend"

step "5/6 trivy gate (HIGH,CRITICAL with a fix available => fail)"
for img in backend frontend; do
  trivy image --quiet --table-mode detailed --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "pragya-library-$img:$VERSION"
done

step "6/6 load images into kind (stands in for 'push to registry')"
for img in backend frontend; do
  "$ROOT/scripts/kind-load.sh" "pragya-library-$img:$VERSION"
done
echo "pipeline passed for version $VERSION"
