#!/usr/bin/env bash
# Smoke test for the running Session 17 API (container, or k8s via port-forward).
#   usage: scripts/smoke-test.sh [base-url]     (default http://localhost:3000)
set -euo pipefail
BASE="${1:-http://localhost:3000}"

for i in $(seq 1 30); do
  curl -sf "$BASE/healthz" > /dev/null && break
  [ "$i" = 30 ] && { echo "FAIL: never healthy"; exit 1; }
  sleep 1
done

fails=0
pass() { echo "PASS  $*"; }
fail() { echo "FAIL  $*"; fails=$((fails + 1)); }

body=$(curl -s "$BASE/")
grep -q '"app":"pragya-devsecops-demo"' <<< "$body" && pass "GET / -> $body" || fail "GET / -> $body"

uid=$(sed -n 's/.*"uid":\([0-9]*\).*/\1/p' <<< "$body")
[ -n "$uid" ] && [ "$uid" != 0 ] && pass "process is not root (uid=$uid)" || fail "process runs as uid '$uid'"

hdrs=$(curl -sI "$BASE/healthz")
grep -qi '^x-content-type-options: nosniff' <<< "$hdrs" && pass "security headers present" || fail "security headers missing"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'content-type: application/json' \
  -d '{"title":"smoke","body":"posted by the smoke test"}' "$BASE/notes")
[ "$code" = 201 ] && pass "POST /notes -> 201" || fail "POST /notes -> $code"

code=$(curl -s -o /dev/null -w '%{http_code}' -X POST -d '{broken' "$BASE/notes")
[ "$code" = 400 ] && pass "bad JSON -> 400" || fail "bad JSON -> $code"

echo "smoke test finished with $fails failure(s)"
exit "$fails"
