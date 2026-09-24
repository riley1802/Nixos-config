# Plugin source audit

Audited on 2026-09-24. Third-party plugin files are pinned by immutable Git
revision and Nix hash in `plugins.nix`.

## Included

- Backpacks — MIT, WheteThunger/Backpacks, active in 2026.
- RemoverTool — MIT, MONaH-Rasta/RemoverTool, active in 2026.
- RecycleManager — MIT, WheteThunger/RecycleManager, active in 2026.

Locally authored and source-controlled:

- NixosCore — LAN auto-admin, PvE protections, player rules, respawn loadout,
  homes, private markers, death notices, and help.
- NixosEconomy — gather/loot/stack/craft/cook/research/durability rates,
  cooker splitting/fuel, and gather HUD.
- NixosWorld — time, weather, population, event, NPC, and vehicle rules.

## Deliberately not redistributed

- TruePVE and NTeleportation: current source is available but no license is
  declared.
- Group Crafting and current Quick Smelt: free downloads, but no source license
  is declared.
- Better Loot: uMod metadata says MIT, but its current source repository does
  not contain a license file. The exact loot behavior is implemented locally.
- Furnace Splitter and Death Notes: public downloads exist, but the current
  authoritative source/version chain is not sufficiently clear for immutable
  redistribution.
- Legacy Gather Manager: unlicensed and stale; only its missing
  `dispenser.scale` behavior is implemented locally.

Exact uncovered behavior belongs in the source-controlled custom plugin suite,
not in unpinned marketplace downloads.
