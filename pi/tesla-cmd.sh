#!/usr/bin/env bash
# Send a signed vehicle command through an on-demand tesla-http-proxy.
# Usage: tesla-cmd.sh <vin> <command> <json-params>   (Bearer <redacted> on stdin)
# Prints the proxy response body on stdout; errors go to stderr.
#
# Runs on the SIGNING HOST -- the machine that holds private-key.pem.
# The proxy is started on demand, bound to localhost only, and stopped
# on exit, so the signing port is never exposed.
set -euo pipefail
VIN="$1"; CMD="$2"; PARAMS="${3:-{}}"
TOKEN=<redacted>
[ -n "$TOKEN" ] || { echo "no token on stdin" >&2; exit 2; }
KEYDIR="${TESLA_KEY_DIR:-$HOME/tesla-key}"
PORT="${TESLA_PROXY_PORT:-18766}"
cleanup() { docker stop tesla-cmd-proxy >/dev/null 2>&1 || true; }
trap cleanup EXIT
docker run -d --rm --user $(id -u):$(id -g) --name tesla-cmd-proxy \
  -v "$KEYDIR:/config:ro" \
  -p "127.0.0.1:${PORT}:4443" \
  tesla/vehicle-command \
  -tls-key /config/proxy-tls-key.pem -cert /config/proxy-tls-cert.pem \
  -key-file /config/private-key.pem -host 0.0.0.0 -port 4443 >/dev/null
for _ in $(seq 1 40); do
  if (echo > /dev/tcp/127.0.0.1/$PORT) 2>/dev/null; then break; fi
  sleep 0.5
done
RESP=$(curl -sk -w "\n%{http_code}" -X POST \
  "https://127.0.0.1:${PORT}/api/1/vehicles/${VIN}/command/${CMD}" \
  -H "Authorization: Bearer ${TOKEN}" \
  -H "Content-Type: application/json" \
  --data "$PARAMS" --max-time 60)
CODE=$(printf "%s" "$RESP" | tail -1)
BODY=$(printf "%s" "$RESP" | sed '$d')
if [ "$CODE" != "200" ]; then
  echo "proxy HTTP $CODE: $BODY" >&2
  exit 3
fi
printf "%s\n" "$BODY"
