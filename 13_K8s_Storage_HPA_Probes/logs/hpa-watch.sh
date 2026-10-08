#!/bin/bash
# $1 namespace, $2 hpa name, $3 outfile ; prints a get hpa row every 15s with time
ns=$1; h=$2; out=$3
kubectl -n $ns get hpa $h | head -1 | sed 's/^/TIME      /' > $out
while true; do
  echo "$(date +%H:%M:%S)  $(kubectl -n $ns get hpa $h --no-headers)" >> $out
  sleep 15
done
