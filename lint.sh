#!/usr/bin/env bash
# Lints each URL with GET $API/v1/lint and fails on the chosen verdict.
set -euo pipefail

case "$FAIL_ON" in fail|warn) ;; *) echo "::error::fail-on must be fail or warn"; exit 2 ;; esac
case "$METHOD" in GET|POST|get|post) ;; *) echo "::error::method must be GET or POST"; exit 2 ;; esac
command -v jq >/dev/null || { echo "::error::jq is required on the runner"; exit 2; }

method="$(printf '%s' "$METHOD" | tr '[:lower:]' '[:upper:]')"
out="$(mktemp)"
trap 'rm -f "$out"' EXIT

rank() { case "$1" in pass) echo 0 ;; warn) echo 1 ;; *) echo 2 ;; esac; }
worst=pass
summary="${GITHUB_STEP_SUMMARY:-/dev/null}"
auth=()
if [ -n "$TOKEN" ]; then
  echo "::add-mask::$TOKEN"
  auth=(-H "Authorization: Bearer $TOKEN")
fi
echo "## x402 lint" >>"$summary"

while IFS= read -r url; do
  url="$(printf '%s' "$url" | tr -d '[:space:]')"
  [ -z "$url" ] && continue
  body=""
  for attempt in 1 2 3 4; do
    code=$(curl -sS -o "$out" -w '%{http_code}' -G ${auth[@]+"${auth[@]}"} \
      -H "User-Agent: alalanet-x402-lint-action/1" \
      --data-urlencode "url=$url" --data-urlencode "method=$method" \
      "$API/v1/lint") || code=000
    body="$(cat "$out" 2>/dev/null || true)"
    [ "$code" = 429 ] || [ "$code" = 000 ] || break
    sleep $((attempt * 10))
  done
  if [ "$code" != 200 ]; then
    echo "::error::lint of $url failed: HTTP $code $(printf '%s' "$body" | jq -r '.hint // .error // empty' 2>/dev/null)"
    worst=fail
    continue
  fi
  verdict=$(jq -r '.verdict' <<<"$body")
  echo "$url: $verdict ($(jq -r '"\(.passed) passed, \(.warnings) warnings, \(.failed) failed"' <<<"$body"))"
  jq -r '.checks[] | select(.level != "pass") | "::\(if .level == "fail" then "error" else "warning" end) title=x402 lint \(.id)::\(.message)\(if .fix then " Fix: \(.fix)" else "" end)"' <<<"$body"
  {
    echo "### \`$url\` — **$verdict**"
    echo
    echo "| level | check | message | fix |"
    echo "|---|---|---|---|"
    jq -r '.checks[] | "| \(.level) | `\(.id)` | \(.message | gsub("\\|"; "/")) | \((.fix // "") | gsub("\\|"; "/")) |"' <<<"$body"
    echo
  } >>"$summary"
  [ "$(rank "$verdict")" -gt "$(rank "$worst")" ] && worst=$verdict
done <<<"$URLS"

echo "verdict=$worst" >>"${GITHUB_OUTPUT:-/dev/null}"
echo "Full report and fixes: $API/lint" >>"$summary"
if [ "$(rank "$worst")" -ge "$(rank "$FAIL_ON")" ]; then
  echo "::error::x402 lint verdict: $worst"
  exit 1
fi
echo "x402 lint verdict: $worst"
