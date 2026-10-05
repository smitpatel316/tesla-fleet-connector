# Charging rates — reference template for trip cost optimization

Copy this file to `charging-rates.md` and fill in YOUR verified numbers.
Network defaults below are starting points only. Per-site pricing is what
actually matters: Tesla prices each Supercharger individually with
time-of-use tiers, and ChargePoint prices are set per station by the site
host. **Always confirm the specific stops at planning time** (Tesla app /
in-car pin / Tesla's public location pages show per-site Supercharger
rates; network apps for the rest).

Neither the Tesla Fleet API nor OpenChargeMap carries per-site $/kWh
(verified: the Fleet API has no pricing endpoint, and a full scan of OCM
POI records found zero price/cost/fee fields) — so this book is the
source of truth for cost comparisons, maintained by hand.

## Your primary charging
- Rate: **$___/kWh** — where you usually charge (verified YYYY-MM-DD).
- This is your typical $/kWh and the practical baseline for trip
  comparisons: a public stop only "wins" if it beats this (or is free).

## Your overnight fallback
- Rate: **$___/kWh** — e.g. apartment/garage Level 2.
- Wins on convenience (overnight, zero detour), not on price.

## Tesla Supercharger (Tesla-driver rate)
- Per-site pricing, up to 4 time-of-use tiers at some sites.
- California typical: ~$0.40-0.65/kWh peak; deep off-peak (often 12am-4am)
  as low as ~$0.21/kWh at some sites. Flat-rate sites ~$0.42/kWh.
- National average ~$0.25-0.45/kWh.
- Non-Tesla EVs pay up to ~52% more at the same stall.

## Electrify America
- Guest $0.48/kWh; Pass+ member $0.36/kWh (Pass+ monthly fee reported
  $4-7/mo — verify current).
- Per-minute states: $0.19/min at ≤90 kW, $0.37/min above 90 kW
  (Pass+: $0.15 / $0.29).

## EVgo
- Guest ~$0.42-0.45/kWh; member ~$0.33-0.34/kWh (plan ~$7-8/mo — verify).

## ChargePoint
- Host-set per station, no central pricing or membership.
- Typical DC $0.35-0.55/kWh; Level 2 often $0.30-0.50/kWh or **free**
  (workplaces, hotels, malls).

## Blink
- ~$0.49/kWh guest; ~$0.39/kWh member.

## Verified per-site log
Fill at trip-planning time: site name, date checked, $/kWh, time-of-use
windows, source (car screen / Tesla app / network app / public page).

| Site | Date | $/kWh | ToU windows | Source |
|------|------|-------|-------------|--------|
|      |      |       |             |        |
