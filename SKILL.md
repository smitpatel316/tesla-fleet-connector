---
name: "tesla"
description: "Read a Tesla vehicle's live state and send remote commands via Tesla's official Fleet API."
icon: "tesla"
metadata: { "includeInPrompt": false }
---

# Tesla (Fleet API connector)

## Purpose
Use `tesla-api` to list vehicles, read live state (battery, charging, location, locks, climate), wake the car, and send signed remote commands — all through Tesla's official Fleet API.

## Tooling
Use:

```sh
tesla-api <subcommand> [options]
```

Core subcommands:
- `auth-url`
- `exchange '<callback-url>'`
- `vehicles`
- `state --vin '<VIN>'`
- `chargers --vin '<VIN>'`
- `ocm [--vin '<VIN>' | --lat <f> --lon <f>] [--radius <mi>] [--limit <n>]`
- `wake --vin '<VIN>'`
- `command --vin '<VIN>' --command <name> [--param k=v ...]`

JSON output contract:
- `auth-url`: prints the authorize URL on stdout (first line).
- `exchange`: prints `ok`, granted `scopes`.
- `vehicles`: prints one JSON object per line: `id`, `vin`, `display_name`, `state`.
- `state`: prints a human summary plus a final `RAW_JSON:` line with the full `vehicle_data` response.
- `chargers`: prints Superchargers + destination chargers near the car's current
  location (Tesla server-side), sorted by distance, with live stall counts.
- `wake` / `command`: print `ok` and the returned `response`/`result`.

## Signed commands
`command` shells out to a signing host over SSH (`TESLA_SSH_HOST`,
default `budupi`) and runs `TESLA_CMD_SCRIPT` (default
`~/tesla-key/tesla-cmd.sh`, see `pi/`) there. The OAuth token is passed on
SSH stdin, never on the command line. The private key never leaves the
signing host. If `TESLA_PARTNER_DOMAIN` is set, pairing hints point at
`https://tesla.com/_ak/<domain>`.

## Road-trip charging
- `chargers` is the trip-planning primitive: query it at the trip start, and
  re-query en route as the car moves (it always reflects the car's current
  position, not a fixed point).
- Limits: the Fleet API exposes charger *locations*, distances, and live
  stall counts, but **no per-site pricing** and **no
  charging-history/invoices endpoint** on this API host
  (`/api/1/charging/history` and `/api/1/charging/sessions` both 404).
  For cost optimization at planning time, combine `chargers` output with a
  rate book like `charging-rates.example.md` (network defaults + a verified
  per-site log — confirm each stop in the Tesla app / in-car pin / Tesla's
  public location pages, which do publish per-site Supercharger rates) and
  with the car's own `charge_state` data (`charge_energy_added`,
  `charger_power`) to estimate kWh needed per leg. Neither API carries
  pricing (a full scan of OpenChargeMap POI records found zero
  price/cost/fee fields).

- `ocm`: prints third-party charging sites near a point from OpenChargeMap,
  with operator, connector types (NACS/CCS/CHAdeMO/J1772), power kW, and
  status. Key in config.json as `ocm_api_key` (600, never printed).

## Third-party chargers (non-Tesla networks)
- Primary source is `ocm` (OpenChargeMap; API key stored in the locked
  config): operator + connector types + kW + quantity + status for
  ChargePoint, EVgo, Blink, EV Connect, Electrify America, etc. Takes
  `--vin` (uses the car's drive_state location) or explicit `--lat/--lon`
  for any trip stop. Community-maintained data: check verification dates
  on RAW_JSON for stale entries, and expect some duplicates from multiple
  data providers.
- Fallback: a places/POI search skill (e.g. `local-search --query "EV
  charging station" --location "<area>"`) for discovery when OCM coverage
  is thin.
- Connector check: this connector was built for a NACS-native Model Y;
  `ocm` shows connector types per site, so verify NACS (or CCS-with-adapter)
  before routing to a non-Tesla stop.

## Auth
- OAuth tokens live in `$TESLA_CONFIG_DIR` or `~/.config/tesla/` (700 dir,
  600 files). The CLI refreshes the access token automatically. Never print
  tokens.
- Client ID/secret come from your own Tesla developer app
  (developer.tesla.com). Start from `config.example.json`; never commit the
  real config.
- If not connected: run `tesla-api auth-url`, open the URL and sign in,
  then `tesla-api exchange '<the localhost callback URL from the address
  bar>'`.
- For signed commands, the app's public key is served from your partner
  domain (see `pi/SETUP.md`); the private key signs commands through
  Tesla's `vehicle-command` proxy, run on-demand on the signing host by
  `pi/tesla-cmd.sh` (official Docker image, token passed over SSH stdin,
  proxy bound to the signing host's localhost only).

## Operating Rules
1. If VIN is not given, call `vehicles` and ask the user to pick one when multiple exist.
2. `state` on a sleeping car returns the last cached data — say so explicitly, with the data's timestamp. Wake ONLY on explicit request (a wake is billable and drains the battery).
3. `command` needs the app's virtual key paired to the car (one-time phone step at `https://tesla.com/_ak/<your-partner-domain>`, plus the domain registered as a partner). Until pairing succeeds, commands fail — surface the error and the pairing step instead of retrying.
4. Approval gate: reads run freely. `wake` and every `command` need explicit go-ahead in chat first. `honk_horn` / `flash_lights` may proceed from a clear, unambiguous request without a second confirmation; lock/unlock, climate, and anything charging-related always need explicit confirmation. Never invent a command that wasn't asked for.
5. Keep API use light: on-demand reads only, never a polling loop. Tesla's $10/month credit covers this comfortably; polling would blow past it.
6. State observations carry raw + UTC + user-local timestamps.
7. Never print tokens, the client secret, or the private key. Never write them to logs, memory, or chat.
