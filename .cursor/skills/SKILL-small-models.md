---
name: "nixos-managing"
description: "Manage this NixOS computer (config in /etc/nixos) with the nixctl command. Use for any NixOS task, even small ones: install or remove a program, turn a service on or off, change a setting, fix a failed rebuild or broken service, update, free disk space, speed things up, roll back, reorganize the config into strict modules, or set up nixctl. Use it in Cursor whenever the user edits /etc/nixos or asks to change this machine. Small local models (LFM3 1.7B in Pi or Hermes) can follow Part 1."
---

# NixOS managing

This computer runs NixOS. Its whole setup is text files in `/etc/nixos`.
You change it with one command: `nixctl`.
nixctl checks, builds and tests every change. If something breaks, it puts the old system back by itself.

## Rules

1. Use `nixctl` for every step. Never run `nixos-rebuild`, `nix-env`, `nix profile`, or `sudo` yourself.
2. Editing a file changes nothing yet. Run `nixctl apply "what you changed"` to make it real.
3. Read the last lines of every nixctl output.
   - `RESULT: OK` means it worked.
   - `RESULT: FAIL` means it did not work.
   - `NEXT:` tells you what to do now. Do it.
4. Before you write an option name, run `nixctl option NAME`. If the result is FAIL, that option does not exist. Do not use it.
5. Never edit: `hardware-configuration.nix`, any `stateVersion` line, files in `secrets/`, `flake.lock`, `flake.nix`, `tools/`.
6. Never write a password, token, or key into a `.nix` file.
7. Edit files only in `modules/` and `hosts/`. Each module file holds everything for one thing.
8. If the same step fails 3 times, stop. Run `nixctl undo`. Tell the user the last `ERROR:` line.

## Start here

Run `nixctl map` first. It lists every module, whether it is on, and what it does.

If the shell says `nixctl: command not found`, stop. Tell the user: "nixctl is not set up. Ask Claude to run the nixos-managing setup."

## Commands

| Command | What it does |
| --- | --- |
| `nixctl map` | List modules, on or off, and what each does |
| `nixctl status` | Running version, unsaved edits, broken services, disk space |
| `nixctl search WORD` | Find the exact name of a program |
| `nixctl option NAME` | Check an option exists; show its type, default and current value |
| `nixctl logs NAME` | Last log lines of a service |
| `nixctl pkg add NAME` | Add a program to the programs list |
| `nixctl pkg remove NAME` | Remove a program from the programs list |
| `nixctl new GROUP/NAME "what it does"` | Make a new module file (off until enabled) |
| `nixctl enable GROUP/NAME` | Turn a module on |
| `nixctl disable GROUP/NAME` | Turn a module off |
| `nixctl check` | Find mistakes fast. Changes nothing |
| `nixctl apply "message"` | Build, test, keep only if healthy, save in git |
| `nixctl undo` | Throw away edits that were not applied yet |
| `nixctl rollback` | Go back to the previous working version |
| `nixctl update` | Update all software, then apply |
| `nixctl clean` | Delete old versions to free disk space |
| `nixctl audit` | List ways to save disk, speed up, and tidy the config |

## Recipes

### Install a program

1. `nixctl pkg add firefox`
2. If that says FAIL: `nixctl search firefox`, then `nixctl pkg add` with the exact name from the first column.
3. `nixctl apply "add firefox"`

You can make several changes, then run `nixctl apply` once for all of them.

### Remove a program

1. `nixctl pkg remove firefox`
2. `nixctl apply "remove firefox"`

If it says the program is not in the list, a module installs it. Run `nixctl map` and turn that module off instead.

### Turn a module on or off

1. `nixctl map` (find the name, for example `services/arr/jellyfin`)
2. `nixctl enable services/arr/jellyfin` or `nixctl disable services/arr/jellyfin`
3. `nixctl apply "turn on jellyfin"`

### Change a setting

1. `nixctl map` (find the module that owns it)
2. Read that module file.
3. `nixctl option services.arr.jellyfin` (lists the real option names)
4. `nixctl option services.arr.jellyfin.openFirewall` (shows its type and current value)
5. Edit or add the line inside `config = lib.mkIf cfg.enable { ... };`
6. `nixctl apply "jellyfin: open firewall"`

### Add a new service

1. `nixctl option services.NAME` (NixOS has it if the list contains `enable`)
2. `nixctl new services/NAME "What it is. Web page on port PORT."`
3. Put its settings inside `config = lib.mkIf cfg.enable {` and `};` in the new file. Copy the shape of the example below.
4. `nixctl enable services/NAME`
5. `nixctl apply "add NAME"`

### Something is broken

1. `nixctl status` (shows broken services)
2. `nixctl logs NAME` (read the error)
3. Broke right after the last change? Run `nixctl rollback`.
4. Otherwise: find the module with `nixctl map`, fix the setting, run `nixctl apply "fix NAME"`.

### Free disk space

`nixctl clean`

### Update everything

`nixctl update` (can take a long time; wait for RESULT)

### Make it faster or smaller

1. `nixctl audit`
2. Do ONE `FIX:` line, then `nixctl apply "..."`. Then the next one.
3. Skip any FIX that says "needs Claude".

## Example module

File `modules/services/arr/jellyfin.nix`:

```nix
# Jellyfin media server. Web page on port 8096.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.arr.jellyfin;
in
{
  options.my.services.arr.jellyfin.enable = lib.mkEnableOption "Jellyfin media server";

  config = lib.mkIf cfg.enable {
    services.jellyfin.enable = true;
    services.jellyfin.openFirewall = false;
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8096 ];
  };
}
```

- Line 1 says what the module does.
- The file path `modules/services/arr/jellyfin.nix` matches the name `my.services.arr.jellyfin`.
- Every setting goes inside `config = lib.mkIf cfg.enable { ... };`.
- Each line ends with `;`.

## Too big for you

Stop and say "This needs Claude." when the task needs any of these:

- moving, renaming or splitting files
- editing `flake.nix`, `tools/`, `packages/` or `secrets/`
- a FIX that says "needs Claude"
- an error you could not fix in 3 tries

## Report

End with exactly these three lines:

```text
Done: <what changed, in one line>
Result: <the RESULT line from nixctl>
Undo: nixctl rollback
```

<!-- END OF CORE: small models stop reading here. Everything below is for Claude and other large models. -->
