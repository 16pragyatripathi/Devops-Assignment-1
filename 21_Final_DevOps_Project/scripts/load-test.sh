#!/usr/bin/env bash
# Generates API traffic through the Ingress (kind maps host port 8081 -> ingress-nginx :80)
# Usage: scripts/load-test.sh [requests] [parallel]
N="${1:-2000}"; P="${2:-20}"
URL="http://127.0.0.1:8081"
HOST="pragya-library.local"
seq "$N" | xargs -P "$P" -I{} curl -s -o /dev/null -w '%{http_code}\n' -H "Host: $HOST" "$URL/api/books" | sort | uniq -c
