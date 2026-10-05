# tesla-fleet-connector

A lean, stdlib-only Python CLI — plus an agent skill definition — that turns
a Tesla vehicle into something an AI agent can work with: live state reads,
charger discovery, and gated remote commands, all through Tesla's official
**Fleet API**. Built as the car connector for a personal AI agent (Muse).

No dependencies. No paid third-party service in the middle.

## What it does

| Area | Command | Notes |
|---|---|---|
| OAuth | `tesla-api auth-url` / `exchange` | Authorization-code flow, auto token refresh |
| Inventory | `tesla-api vehicles` | VIN, display name, state per vehicle |
| Live state | `tesla-api state --vin VIN` | Battery, charging, location, locks, climate, odometer — human summary + `RAW_JSON:` |
| Tesla chargers | `tesla-api chargers --vin VIN` | Superchargers + destination chargers near the car, live stall counts |
| Third-party chargers | `tesla-api ocm [--vin VIN \| --lat f --lon f]` | OpenChargeMap: operator, connector types (NACS/CCS/CHAdeMO/J1772), kW, status |
| Wake | `tesla-api wake --vin VIN` | Billable — gated behind explicit approval |
| Commands | `tesla-api command --vin VIN --command NAME [--param k=v]` | Signed remote commands — gated behind explicit approval |

## Architecture

```
agent ──► tesla-api CLI ──► Tesla Fleet API ──► the car
              │                    (reads: vehicle_data, nearby_charging_sites;
              │                     writes: wake_up)
              └── signed commands ──► SSH ──► signing host (e.g. Raspberry Pi)
                                                 │
                                                 ▼
                                        tesla-cmd.sh starts the official
                                        tesla/vehicle-command Docker proxy
                                        on demand (localhost-only), sends
                                        the signed command, stops it.
                                        The private key never leaves
                                        this host; the OAuth token travels
                                        over SSH stdin, never in argv.
```

Reads are plain HTTPS to the Fleet API. Writes need the app's **virtual key**
paired to the car — a one-time phone step at
`https://tesla.com/_ak/<your-partner-domain>` after registering the domain
as a partner and serving the app's public key from it (see `pi/SETUP.md`).

## Quick start

```sh
# 1. Create a Tesla developer app at developer.tesla.com (get client_id/secret)
# 2. Configure
cp config.example.json ~/.config/tesla/config.json
chmod 600 ~/.config/tesla/config.json
#   ... fill in client_id, client_secret (and ocm_api_key if you want third-party chargers)

# 3. Connect the car (OAuth)
./tesla-api auth-url          # open the URL, sign in
./tesla-api exchange '<paste the localhost callback URL>'

# 4. Read
./tesla-api vehicles
./tesla-api state --vin <VIN>

# 5. (optional) Signed commands: set up pi/ on a signing host, then
export TESLA_SSH_HOST=<signing-host> TESLA_PARTNER_DOMAIN=<your-domain>
./tesla-api command --vin <VIN> --command flash_lights
```

## Trip charging

Two primitives, designed to be combined:

- **`chargers`** — Tesla's own Supercharger/destination-charger locations
  near the car with live stall counts. Re-query en route; it always reflects
  the car's current position.
- **`ocm`** — third-party networks (ChargePoint, EVgo, Electrify America,
  Blink, …) from OpenChargeMap with connector types and power levels.

Neither API publishes per-site **$/kWh**, so cost optimization runs off a
hand-maintained rate book — see `charging-rates.example.md` (network
defaults + a verified per-site log; confirm stops in the Tesla app or
in-car at planning time).

## Operating rules (for agent use)

These are encoded in `SKILL.md` and worth restating:

1. **Reads run freely; `wake` and every `command` need explicit go-ahead.**
   `honk_horn`/`flash_lights` may proceed from a clear, unambiguous request;
   lock/unlock, climate, and charging-related commands always need explicit
   confirmation. Never invent a command.
2. `state` on a sleeping car returns last cached data — say so with the
   data's timestamp. Wake only on explicit request (billable, drains battery).
3. On-demand reads only, never a polling loop — Tesla's $10/month API credit
   covers normal agent use; polling would blow past it.
4. Never print tokens, the client secret, or the private key. Tokens live in
   `~/.config/tesla/` (700 dir, 600 files); the private key lives only on
   the signing host.

## Layout

```
tesla-api                 the CLI (Python 3, stdlib only)
SKILL.md                  agent skill definition (drop into a skills dir)
config.example.json       config template (client_id/secret, OCM key)
charging-rates.example.md rate-book template for trip cost optimization
pi/tesla-cmd.sh           on-demand signing-proxy script (signing host)
pi/SETUP.md               signing-host setup: keypair, public-key serving,
                          partner domain, phone pairing
```

## License

MIT — see [LICENSE](LICENSE).
