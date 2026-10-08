#!/usr/bin/env bash
# Smoke test: call the running API and check a few real responses.
# Used by the CI job, against the Docker container, and after the k8s deploy.
#   usage: scripts/smoke-test.sh [base-url]     (default http://localhost:3000)
set -euo pipefail
BASE="${1:-http://localhost:3000}"

echo "waiting for $BASE/healthz ..."
for i in $(seq 1 30); do
  if curl -sf "$BASE/healthz" > /dev/null; then break; fi
  if [ "$i" = 30 ]; then echo "FAIL: app never became healthy"; exit 1; fi
  sleep 1
done

fails=0
check() {   # check <path> <expected-http-code> <text-that-must-appear>
  local body code
  body=$(curl -s -w '\n%{http_code}' "$BASE$1")
  code=$(tail -n1 <<< "$body")
  body=$(sed '$d' <<< "$body")
  if [ "$code" = "$2" ] && grep -q -- "$3" <<< "$body"; then
    echo "PASS  $1 -> $code $body"
  else
    echo "FAIL  $1 -> expected $2 containing '$3', got $code $body"
    fails=$((fails + 1))
  fi
}

check /healthz                        200 '"status":"ok"'
check /                               200 '"app":"pragya-cicd-demo"'
check '/grade?marks=82'               200 '"letter":"A+"'
check '/sgpa?courses=4:85,3:72,2:91'  200 '"sgpa":8.89'
check '/grade?marks=150'              400 'between 0 and 100'

echo "smoke test finished with $fails failure(s)"
exit "$fails"
