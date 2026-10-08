#!/bin/zsh
# promql '<query>' [label ...] : run an instant PromQL query against the port-forwarded Prometheus (localhost:3302)
q="$1"; shift
labels=("$@")
curl -s localhost:3302/api/v1/query --data-urlencode "query=$q" | jq -r --argjson l "$(printf '%s\n' "${labels[@]}" | jq -R . | jq -sc 'map(select(length>0))')" '
  if .status != "success" then "error: \(.error)" else
  .data.result[] | (if ($l|length)>0 then [ $l[] as $k | (.metric[$k] // "-") ] | join("  ") else (.metric|tostring) end) + "  =>  " + (.value[1] | tonumber | if . == (.|floor) then tostring else (.*10000|round/10000|tostring) end) end'
