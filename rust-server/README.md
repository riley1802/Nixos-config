# Rust LAN PvE server

The Linux Mint direct-connect gate passed, so Carbon and the declared gameplay
rules are enabled.

## Minimal client test

1. Install Rust in Steam on the Linux Mint computer and select a current Proton
   version.
2. In Steam, open Rust's **Properties**, paste this into **Launch Options**
   (do not run it in a terminal):

   ```text
   bash -c 'exec "${@/Rust.exe/RustClient.exe}"' -- %command%
   ```

3. Start Rust. Do not use the normal server browser; insecure servers are not
   listed there.
4. Press `F1`, then connect directly to the current wired-LAN address:

   ```text
   client.connect 192.168.50.101:28015
   ```

   Rust's Proton/Mono DNS layer did not resolve `nixos.local` during the
   validated client test, even though mDNS works on the native Linux host.
   Re-check the server's address with `ip -4 address show enp132s0` if DHCP
   changes it.

The client successfully loaded into the temporary size-4000 procedural world
without an EAC rejection on 2026-09-24.

## Service commands

```console
systemctl show rust-lan-server \
  -p ActiveState -p SubState -p NRestarts -p MemoryCurrent -p MemoryMax
journalctl -u rust-lan-server -f
pkexec systemctl restart rust-lan-server
pkexec rust-server-backup rolling
pkexec rust-server-wipe
```

Avoid `systemctl status rust-lan-server`: Rust requires the RCON password in its
process arguments, which `status` can display.

`rust-server-wipe` requires typing `WIPE`, announces the wipe, saves, creates a
90-day pre-wipe backup, removes only map/save/player-state data, and retains
blueprints, homes, and backpacks. Rolling backups run every six hours and are
retained for 14 days. Daily warnings start at 03:30 America/Chicago; the server
saves, updates, backs up, and restarts at 04:00.

Health metrics are written to
`/var/lib/rust-server/metrics/rust-server.prom`. Game logs are rotated daily,
compressed, and retained for 30 rotations.

## Map

The locked world is procedural size 4000, seed 1337. The curation source
reports 209 monuments, eight caves, five islands, 55% land, and balanced biome
coverage:

https://rustmaps.com/map/4000_1337

The generated RCON password is encrypted in
`secrets/rust-server.yaml`. Decrypt it only on the host:

```console
pkexec env SOPS_AGE_SSH_PRIVATE_KEY_FILE=/etc/ssh/ssh_host_ed25519_key \
  sops decrypt --extract '["rust-server"]["rcon-password"]' \
  /etc/nixos/secrets/rust-server.yaml
```

## Authoritative references

- Facepunch server setup:
  https://wiki.facepunch.com/rust/creating-a-server
- Facepunch EAC-disabled client:
  https://support.facepunchstudios.com/hc/en-us/articles/15041503601437-Launching-Rust-with-EAC-disabled-RustClient-exe
- Carbon production setup:
  https://carbonmod.gg/owners/getting-started
- sops-nix:
  https://github.com/Mic92/sops-nix
