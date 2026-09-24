# Rust LAN PvE server decisions

This file is the authoritative configuration ledger. Values are intentional
unless marked as a staged gate.

## Delivery gates

- First boot a minimal vanilla, EAC-disabled server.
- Before Carbon or gameplay plugins are enabled, prove that the Linux Mint
  client can launch `RustClient.exe` through Proton and connect directly to
  `nixos.local:28015` (fallback: `192.168.50.101:28015`).
- Use free, license-compatible plugin sources. Exact behavior takes priority
  over minimizing custom code when no maintained plugin covers a requirement.

## Access and identity

- Hostname: `NixOS LAN PvE 100x`.
- Description: concise rules/rates summary with `/help` for details.
- Wired LAN only on `enp132s0`; no router forwarding or Tailscale exposure.
- Game UDP: `28015`; query UDP: `28017`; RCON TCP: `28016`.
- EAC/security disabled. Rust+ disabled.
- Maximum concurrent players: 4.
- Any Steam user reachable on the wired LAN may join.
- Every joining player is automatically promoted to owner/admin.
- RCON password is encrypted with sops to the host SSH Ed25519 key.
- Run as locked system user `rust-server` under `/var/lib/rust-server`.

## World

- Procedural map, size 4000.
- Seed 1337 is locked. The size-4000 generation has 209 monuments (23 large,
  18 small), eight caves, five islands, 55% land, a standard ocean/coastline,
  roads, and balanced forest/desert/snow/tundra/jungle coverage.
- Harsh dynamic weather.
- Follow Rust's real-calendar seasonal events.
- 60-minute day and 10-minute moderately bright night.

## Wipes and progression

- Map wipes are manual, except unavoidable save incompatibility/force wipes.
- Never wipe blueprints automatically.
- Save every 5 minutes.
- Blueprints are individual; vanilla starter blueprints.
- Vanilla workbench tiers and tech tree.
- Vanilla research cost with near-instant research duration.

## Gathering

- Trees, ore nodes, and harvestable corpses: 100x per-hit yield and 100x total
  capacity, uniformly across materials.
- Ground pickups and crop harvests: 75x.
- Crop growth: 10x speed.
- Quarries, Giant Excavator, Pump Jacks, and Survey Charges: 75x output.
- Automated extractors: 10x cycle speed with normal fuel consumed per cycle.
- Fishing rewards: 75x; bite/catch speed: 5x.

## Loot

- General quantity baseline: 100x.
- Barrels, crates of every tier, and NPC corpse inventories: 75x.
- Airdrops and explicitly configured major-event rewards: 100x.
- Unspecified event rewards: 75x.
- Three times the vanilla item rolls/slots and 3x rare-item weighting.
- Scrap: 75x. Blueprint drops: disabled. Duplicate item rolls: allowed.
- Use vanilla-derived item pools; no blocked or guaranteed items.
- No additional monument-location multiplier.
- Respawn all loot sources 5x faster.

## Inventory and production

- Fungible items: maximum stack size 100,000,000.
- Exclude weapons, tools, armor, and other condition/attachment-bearing items.
- Crafting: instant.
- Recycling: instant with 75x output yield.
- Smelting/cooking: 200x speed, 5x output yield, vanilla fuel cost.
- Cooker inventories: 3x normal slot count.
- Auto-split cooker input and calculate/insert fuel.
- Equipment durability: 10x effective durability (90% less wear).
- Dropped-item despawn duration: 5x vanilla.

## Building and upkeep

- Stability remains enabled with approximately 3x support tolerance.
- Decay: 5x slower. Upkeep cost: vanilla.
- No extra building-size/entity caps.
- Tool Cupboard authorization remains manual; privilege radius is 5x vanilla.
- Vanilla grades, upgrades, deployable placement, and deployable pickup.
- Authorized owners may remove owned blocks at any time for free with a full
  construction-material refund.

## Combat and raiding

- PvE only; no player damage or friendly fire.
- Native player teams are disabled.
- Player damage to PvE targets: vanilla 1x.
- NPC/animal damage to players: vanilla 1x.
- All vanilla weapons and normal weapon operation.
- Players may damage only structures they own or are authorized for, at any
  time. Other players' structures are always protected.
- No additional offline-only protection.
- Sleepers remain in the world, protected from player damage only.

## Players

- Maximum health: 2x. Health regeneration: 5x.
- Vanilla hunger, thirst, and temperature effects.
- Radiation intensity/damage: 50% of vanilla.
- Sleeping bag and bed cooldowns: disabled.
- Without a selected bag/bed, respawn at a random valid map location.
- Backpacks: 48 slots; contents survive death and map wipes.
- Homes: 3 per player, instant, no cooldown. Player-to-player teleport disabled.
- Clans disabled. Vanilla physical trading only.

### Respawn kit

Grant automatically after every respawn:

- One Assault Rifle with holographic sight and weapon flashlight.
- 1,000 standard 5.56 rifle rounds.
- Metal facemask/chest plate, roadsign kilt/gloves, hoodie, pants, boots, and a
  hazmat suit.
- 50 medical syringes, 20 bandages, and 5 large medkits.
- Salvaged pickaxe, salvaged axe, hammer, and building plan.
- Sleeping bag, 20 cooked meat, full large water jug, and flashlight.
- 10,000 wood, 10,000 stone, 5,000 metal fragments, one Tool Cupboard, one
  sheet-metal door, and one code lock.
- No additional claimable kits.

## NPCs and events

- Animals: 5x population, vanilla health and damage.
- Rideable horses override the animal profile and stay at vanilla population.
- Scientists: 3x population, 2x health, vanilla AI and damage.
- Bradley: 2x frequency, 2x health, vanilla damage, 100x rewards.
- Patrol Helicopter: 2x frequency, 2x health, vanilla damage, 100x rewards.
- Cargo Ship: 5x frequency, vanilla duration/reward rounds, global scientist
  profile, 100x rewards.
- Chinook: 2x frequency, 5-minute locked-crate timer, 100x rewards.
- Automatic airdrops: vanilla frequency, 100x rewards.
- Other vanilla events: enabled with vanilla timing/behavior and 75x rewards.

## Vehicles

- Modular cars: 2x population.
- Minicopters: 5x free world population plus vendor access.
- Scrap Transport Helicopters: 2x free world population plus vendor access.
- Boats: 2x population. Submarines and horses: vanilla availability.
- Surface/underground rail vehicles: 2x population.
- Motorized vehicle fuel use: 50% of vanilla.
- Vehicle decay disabled.
- First claim/use establishes tracked ownership; no locks.
- Remove vehicles after 14 days without use.

## Quality of life

- Aggregated gather HUD.
- Death notices show victim, cause/attacker, weapon, and distance.
- Personal map markers for homes, owned vehicles, latest death, and active PvE
  events; do not reveal other players live.
- No automatic shared authorization.
- Notify owners about NPC/environmental structure damage only.
- Comprehensive `/help` for rules, rates, commands, kits, and administration.
- Carbon operations panel enabled without the plugin marketplace.

## Custom content

- Persistent boosted PvE survival only.
- No custom map/monuments, custom NPC encounters, custom quests, virtual
  economy/GUI shops, rotating game modes, or paid plugins.

## Operations

- Check/apply Rust updates daily at 04:00 America/Chicago.
- Carbon tracks the stable production build; third-party plugins are pinned.
- Restart daily at 04:00 after warnings at 30, 10, 5, and 1 minute.
- Back up every 6 hours and before maintenance/wipes.
- Keep rolling backups 14 days and pre-wipe backups 90 days.
- Crash recovery: restart automatically with rate limiting and alerts; never
  restore a backup automatically.
- Normal logs, daily compression/rotation, 30-day retention.
- Lightweight local health metrics/alerts.
- Hard memory ceiling: 20 GiB.
- No CPU quota; moderately elevated non-real-time CPU and I/O priority.
- Manual wipe command must confirm, announce, save, stop, back up, clear only
  selected map data, retain blueprints/backpacks, restart, and verify health.
