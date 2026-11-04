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
|---|---|
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
1. `nixctl map` (find the name, for example `services/jellyfin`)
2. `nixctl enable services/jellyfin` or `nixctl disable services/jellyfin`
3. `nixctl apply "turn on jellyfin"`

### Change a setting
1. `nixctl map` (find the module that owns it)
2. Read that module file.
3. `nixctl option services.jellyfin` (lists the real option names)
4. `nixctl option services.jellyfin.openFirewall` (shows its type and current value)
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

File `modules/services/jellyfin.nix`:

```nix
# Jellyfin media server. Web page on port 8096.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.jellyfin;
in
{
  options.my.services.jellyfin.enable = lib.mkEnableOption "Jellyfin media server";

  config = lib.mkIf cfg.enable {
    services.jellyfin.enable = true;
    services.jellyfin.openFirewall = false;
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 8096 ];
  };
}
```

- Line 1 says what the module does.
- The file path `modules/services/jellyfin.nix` matches the name `my.services.jellyfin`.
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

```
Done: <what changed, in one line>
Result: <the RESULT line from nixctl>
Undo: nixctl rollback
```

<!-- END OF CORE: small models stop reading here. Everything below is for Claude and other large models. -->

# Part 2: for Claude and other large models

Part 1 is the whole job for small models, and large models use the same `nixctl` commands to apply changes. Part 2 covers design work: the layout rules, converting a repo to this layout, making it leaner, and the files to install. The sections, in order:

| Section | Read when |
|---|---|
| R1 Layout rules | Designing or reviewing any module; before any refactor |
| R2 Module patterns | Writing a module that shares values, adds routes or ports, or builds a package |
| R3 Setup: convert a repo | `nixctl` is missing, or the repo is not in this layout |
| R4 Efficiency playbook | "Make it leaner/faster", audit findings marked "needs Claude" |
| R5 Nix pitfalls | Any non-trivial Nix edit |
| R6 Small models and harnesses | Installing the skill for Pi or Hermes, or tuning it for small models |
| R7 Files to install | During setup (verbatim file contents, including `nixctl`) |

When working on Riley's machine with Claude Code, apply changes with `nixctl apply` like a small model would. It is the safe path for every model, and it keeps git history in step with the running system.

## R1 Layout rules

The goal is a config where every common change is one line in a predictable file. That's what lets a 1.7B model edit it safely, and it's also what makes it easy for Riley to read.

```
/etc/nixos/
  flake.nix                 inputs + one mkHost line per computer; nothing else
  flake.lock
  AGENTS.md                 5 lines pointing agents at nixctl (Pi and Hermes auto-load it)
  hosts/HOST/
    default.nix             control panel: identity, `# nixctl: modules` enable list, stateVersion
    packages.nix            plain package names only (nixctl pkg edits it)
    hardware-configuration.nix   generated; never hand-edited
  modules/
    default.nix             auto-imports every .nix file below it
    core/                   always on, no enable option: nix, boot, system, settings, users, nixctl, overlays
    GROUP/NAME.nix          everything else; off until `my.GROUP.NAME.enable = true`
  packages/NAME.nix         custom package builds, auto-exposed as pkgs.NAME (R2)
  secrets/                  agenix: secrets.nix + *.age
  tools/nixctl.sh           the nixctl script (R7)
```

Rules, and why each one exists:

1. **One feature, one file.** `modules/GROUP/NAME.nix` holds everything that feature needs: service settings, firewall ports, users and groups, systemd overrides, tmpfiles, its `age.secrets` entries, its Tailscale route, its desktop entry. Why: an agent finds everything about a feature in one place, and deleting the file removes the feature completely.
2. **The path is the name.** `modules/services/jellyfin.nix` declares exactly `options.my.services.jellyfin.enable`. `nixctl map/enable/disable` depend on this.
3. **Modules talk only through options.** A module never edits another module's file and never hardcodes another module's port, path or user. Shared values are `my.*` options declared in `modules/core/settings.nix` and set in the host file. Cross-feature wiring uses the hub pattern (R2). Why: this is what "fits together with no glue" means in Nix. It's the same way NixOS's own `networking.firewall.allowedTCPPorts` collects ports from every module.
4. **Explicit dependencies.** If a feature truly needs another, it asserts it:
   `assertions = [ { assertion = config.my.network.tailscale.enable; message = "services/n8n needs network/tailscale (nixctl enable network/tailscale)"; } ];`
   Every module must evaluate both on and off.
5. **A stack is one feature only if its parts are never used apart.** Sonarr, Radarr and the shared media directories can be `services/media.nix`. Jellyfin, which is useful alone, gets its own file.
6. **The host file is a control panel, not a config.** It holds hostname, `my.*` values, the sorted `# nixctl: modules` block, and `system.stateVersion`. No feature settings.
7. **`packages.nix` holds plain names only.** Anything with arguments (`makeDesktopItem`, overrides) belongs to a module.
8. **Groups stay few and obvious:** `core`, `hardware`, `desktop`, `network`, `services`, `apps`, `dev`, `gaming`. A group with one file is fine.
9. **Comments explain why, with a source.** Line 1 is a one-line description (`nixctl map` prints it). Keep Riley's existing style: say why a non-obvious setting exists, plus a URL to the module source or docs. Don't write comments that restate the code. Comments move with the code they explain.
10. **Style.** No `rec`. Use `with pkgs;` only inside a list. Use `lib.mkIf` for conditions. Every `lib.mkForce` gets a comment saying why. Format with the flake's `formatter` (`nixctl` runs it on changed files).

## R2 Module patterns

**Basic module:** the template `nixctl new` writes (shown in Part 1).

**Module with settings:** expose only what callers actually change.
```nix
options.my.services.llama = {
  enable = lib.mkEnableOption "llama.cpp servers";
  port = lib.mkOption { type = lib.types.port; default = 8082; description = "Port of the 1.7B server."; };
};
```

**Shared values:** declare them once in `modules/core/settings.nix`, set them in the host file, and read them anywhere:
```nix
options.my.tailnetHost = lib.mkOption { type = lib.types.str; description = "This computer's MagicDNS name."; };
# hosts/nixos/default.nix:   my.tailnetHost = "nixos.taile9f484.ts.net";
# any module:                N8N_HOST = config.my.tailnetHost;
```

**Hub pattern (many modules feed one):** the hub declares a collection option and generates config from it. Each feature adds its own entry. Example: replacing a hand-maintained list of Tailscale Serve ports.
```nix
# modules/network/tailscale.nix (hub)
options.my.network.tailscale = {
  enable = lib.mkEnableOption "Tailscale";
  serve = lib.mkOption {
    type = lib.types.attrsOf lib.types.port;
    default = { };
    description = "HTTPS routes on the tailnet: name = local port. Each module adds its own.";
  };
};
config = lib.mkIf cfg.enable {
  # ...one script line per route:
  # lib.concatMapStringsSep "\n" (p: ''"$ts" serve --bg --yes --https=${toString p} http://127.0.0.1:${toString p}'') (lib.attrValues cfg.serve)
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = lib.attrValues cfg.serve;
};

# modules/services/n8n.nix (feature): one line, no edit to the hub
my.network.tailscale.serve.n8n = 5678;
```

**Repeated blocks become one generator:**
```nix
# Six copies of wants/after/bindsTo become:
systemd.services = lib.genAttrs [ "qbittorrent" "sonarr" "radarr" "lidarr" "jellyfin" "bazarr" ] (_: {
  wants = [ "media-directories.service" ];
  after = [ "media-directories.service" ];
  bindsTo = [ "media-directories.service" ];
});
```

**Custom packages:** add one overlay in `modules/core/overlays.nix` and one file per package.
```nix
# packages/llama-cpp.nix is a normal callPackage file. A directory with
# package.nix inside works too (packages/uptime-kuma/package.nix + its patch).
nixpkgs.overlays = [
  (final: prev: lib.packagesFromDirectoryRecursive { inherit (prev) callPackage; directory = ../../packages; })
];
```
A file named after an existing attribute (`llama-cpp`, `lidarr`) replaces the nixpkgs version.

**Packages from unstable:** create one instance, in one place, and reuse it. Every `import nixpkgs-unstable { ... }` evaluates a second nixpkgs.
```nix
# modules/core/overlays.nix (needs specialArgs = { inherit inputs; } in flake.nix)
{ inputs, ... }:
let
  unstable = import inputs.nixpkgs-unstable { system = "x86_64-linux"; config.allowUnfree = true; };
in
{
  # One line per package taken from unstable, each with its reason.
  nixpkgs.overlays = [ (final: prev: { inherit (unstable) radarr immich; }) ];
}
```

**Secrets (agenix) stay in the module that uses them:**
```nix
age.secrets.ntfy-auth = { file = ../../secrets/ntfy-auth.age; owner = "ntfy-sh"; mode = "0400"; };
services.ntfy-sh.environmentFile = config.age.secrets.ntfy-auth.path;
```

## R3 Setup: convert a repo to this layout

Run this once per repo. It's large, so confirm the planned module tree with Riley first if he's present. If he isn't, go ahead and leave the plan in the commit message.

1. **Baseline.** Start from a clean tree on a new branch (`git switch -c restructure`). Then record the current system:
   `nix eval --raw .#nixosConfigurations.HOST.config.system.build.toplevel.drvPath > /tmp/before.drv`
2. **Install the tools into the repo.** Extract them from this skill so you aren't hand-copying 700 lines:
   ```bash
   SKILL=<this skill's SKILL.md path>
   x() { awk -v b="<!-- BEGIN $1 -->" -v e="<!-- END $1 -->" '$0==b{f=1;next} $0==e{f=0} f' "$SKILL" | sed '1d;$d'; }
   mkdir -p tools && x tools/nixctl.sh > tools/nixctl.sh && x cfgdiff.sh > /tmp/cfgdiff.sh && chmod +x tools/nixctl.sh /tmp/cfgdiff.sh
   sha256sum tools/nixctl.sh   # must be d38c90083966648adb8c95caab0f6b1f6cab7746f624482ea55ba5a113249b7b
   ```
   If you can't read the skill file from disk, copy the R7 blocks exactly and check the hash. A wrong hash means a copy error.
3. **Create the skeleton** from R7: `flake.nix` changes, `modules/default.nix`, the `modules/core/*` files, `hosts/HOST/default.nix`, `packages.nix`, `AGENTS.md`, `.gitignore`. Then `git mv hardware-configuration.nix hosts/HOST/`. Keep the existing flake inputs, overlays and `specialArgs`, and move overlay code into `modules/core/overlays.nix`.
4. **Move content without changing behavior.** Each feature goes into its own module, wrapped in the enable pattern and enabled in the host file. Move comments together with their code. `git add -A` after each batch, then compare:
   `nix eval --raw .#nixosConfigurations.HOST.config.system.build.toplevel.drvPath > /tmp/after.drv && /tmp/cfgdiff.sh $(cat /tmp/before.drv) $(cat /tmp/after.drv)`
   The target is `IDENTICAL`. Reordering firewall ports and group lists usually still comes out IDENTICAL, because NixOS normalizes them. A `ROOT CAUSE` showing only "same items, different order" is acceptable once you've explained it. Fix anything else before moving on.
5. **Commit the pure restructure** ("restructure: no behavior change; cfgdiff IDENTICAL").
6. **Then improvements, one commit each**, each checked with cfgdiff to show only the intended change: add `modules/core/nixctl.nix`, hub patterns (R2), deduplication, and the audit fixes (R4). Delete dead files (check with `grep -r`), for example a `.sops.yaml` when nothing uses sops.
7. **First switch** has to happen without nixctl, since nixctl isn't installed yet. Riley runs his usual command: `pkexec nixos-rebuild switch --flake /etc/nixos`. After that, `nixctl status` should print `RESULT: OK`. From then on, use `nixctl apply`.
8. **Update the README** so its layout section lists the new tree. Keep the per-service notes, with corrected file paths.
9. **Install the small-model copy** (R6).

nixctl commits locally after every successful apply (`nixctl: <message>`). It never pushes. Riley decides when to push.

## R4 Efficiency playbook

Measure first, change one thing, then measure again. Don't add tweaks you can't verify.

**Less config code**
- Hub options instead of hand-maintained lists (R2). These lists exist when one file names ports or units that belong to other features.
- `lib.genAttrs` or `lib.mapAttrs` for blocks repeated 3 or more times. `nixctl audit` reports repeated 3-line blocks.
- Shared `my.*` values instead of repeated literals (username, tailnet host, media paths).
- Use the NixOS module when one exists (`nixctl option services.NAME`) instead of a hand-written systemd unit.
- Delete what nothing uses: modules that are off and unwanted, stale overlays, unused inputs. Check with `nix flake metadata` and `grep -r`.

**Faster rebuilds**
- See what will be built from source: `nix build --dry-run .#nixosConfigurations.HOST.config.system.build.toplevel 2>&1 | sed -n '/will be built/,/will be fetched/p'`. Each line is a local build. Custom derivations (a custom `llama-cpp` with CUDA, an AppImage override) always build locally. Keep them only when they're needed.
- CUDA packages are unfree, so cache.nixos.org doesn't have them. The NixOS CUDA cache is `https://cache.nixos-cuda.org` with key `cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=`. It mainly covers unstable, so check a path before relying on it: `nix path-info --store https://cache.nixos-cuda.org <out-path>`.
- `documentation.nixos.enable = false;` skips building the options manual on every rebuild. `nixctl option` replaces `man configuration.nix`.
- One nixpkgs instance per input (R2). Give every input `inputs.nixpkgs.follows = "nixpkgs"` when it accepts one.
- Rebuild time shows up in `nixctl apply` ("applied in Ns"), so compare it before and after.

**Less disk**
- `nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };` and `nix.optimise.automatic = true;`
- `boot.loader.systemd-boot.configurationLimit = 10;` (an unlimited boot menu fills `/boot`)
- `nix.settings.min-free` / `max-free` (automatic GC when the disk is nearly full)
- `services.journald.extraConfig = "SystemMaxUse=500M";`
- Find the biggest store paths: `nix path-info -rSh /run/current-system | sort -k2 -h | tail -20`. For containers: `docker system df`.

**Faster system**
- `zramSwap.enable = true;` (compressed RAM swap). `services.fstrim.enable` is already on by default.
- Boot: `systemd-analyze blame | head -15` and `systemd-analyze critical-chain`. Before disabling `NetworkManager-wait-online`, check what orders against `network-online.target` (on Riley's desktop, `dnsproxy` deliberately does).
- Keep the default kernel unless there's a measured reason. `linuxPackages_latest` can break the NVIDIA driver.
- Don't apply untested "performance" toggles (CPU governor, sysctl lists) without a before/after measurement.

## R5 Nix pitfalls

- Flakes only see git-tracked files. A new file needs `git add` (nixctl does this), or the error says "does not exist".
- Never change `system.stateVersion`. It controls data migrations, not package versions.
- Never put secrets in `.nix` files: the store is world-readable. Use agenix (`age.secrets.*`, files in `secrets/`).
- `//` is a shallow merge and replaces nested sets. Use `lib.recursiveUpdate`, or separate definitions and let the module system merge them.
- A bare `if config.x then ...` inside `config` causes infinite recursion. Use `lib.mkIf`.
- `rec { }`: use `let ... in` instead. `import <nixpkgs>` is impure; use the module's `pkgs`.
- Lists from several modules are concatenated in import order, and `modules/default.nix` imports alphabetically. When order matters, use `lib.mkBefore`/`lib.mkAfter` or keep the list in one module.
- Use `/dev/disk/by-id`, `by-uuid` or `by-label` for disks, never `/dev/sdX`.
- Add `--show-trace` to `nix eval` for the full error chain when nixctl's `WHERE:` isn't enough.
- Never guess option names. Use `nixctl option PATH`, which also lists the children of a path.

## R6 Small models and harnesses

**Install for Pi and Hermes.** Small models should get Part 1 only (about 2.5k tokens). Part 2 would just dilute their attention:
```bash
SKILL=<this SKILL.md>
for d in ~/.pi/agent/skills/nixos-managing ~/.hermes/skills/nixos-managing; do
  mkdir -p "$d" && sed '/^<!-- END OF CORE/q' "$SKILL" > "$d/SKILL.md"
done
```
- Pi doesn't always load a skill on its own. Force it with `/skill:nixos-managing`. In Hermes the command is `/nixos-managing`.
- Start the agent in `/etc/nixos`. Both harnesses then auto-load `AGENTS.md` from the repo (R7), which points the model at `nixctl map`.
- LFM3-1.7B settings (Liquid's recommendation): `--temp 0.1 --top-k 50 --repeat-penalty 1.1`. In Hermes, set `agent.tool_use_enforcement true`, or the model tends to describe commands instead of running them.

**Install for Cursor.** Cursor is a large model, so it gets this whole file, not the Part 1 cut. One copy stays in the repo; Cursor finds it through symlinks:

```bash
mkdir -p ~/.cursor/skills /etc/nixos/.cursor/skills
ln -sfn /etc/nixos/agent/nixos-managing ~/.cursor/skills/nixos-managing
ln -sfn ../../agent/nixos-managing /etc/nixos/.cursor/skills/nixos-managing
```

`~/.cursor/skills/nixos-managing` is the personal skill (every project). `/etc/nixos/.cursor/skills/nixos-managing` is the project skill (this repo). A second copy of the file would drift away from the scripts embedded below.

**Why Part 1 is shaped this way:** short literal lines, one command per step, no judgment calls. `RESULT:`/`NEXT:` lines turn every tool output into a next instruction. Option names are checked by `nixctl option` instead of recalled. Every risky step (build, activation, rollback, git) is inside nixctl, not in the model's hands. When you change Part 1, keep it that way: add a recipe or a nixctl subcommand rather than prose.

**Unattended use (the n8n watchdog idea):** nixctl's commands make a natural safe action menu. `status`, `logs` and `audit` are read-only. `rollback` and `clean` are bounded fixes. `apply` only keeps a change that passes the health check, and its 5-minute dead-man timer restores the old system if the agent dies mid-switch.

**What nixctl apply does, so you can explain failures:**
1. Stages all files and refuses edits to hardware-configuration, stateVersion, secrets or flake.lock, and plain-text secrets.
2. Formats the changed `.nix` files.
3. Evaluates. On error it prints `ERROR`, the code lines, `WHERE: file:line` and a specific `NEXT`.
4. Builds as the user and prints `nix store diff-closures`.
5. Runs as root (passwordless sudo for nixctl only): arms the revert timer, runs `switch-to-configuration test` in its own systemd unit, waits for jobs to settle, then compares failed and auto-restarting units against the list from before. Any new broken unit means it re-activates the old system and returns FAIL with that unit's logs. Otherwise it disarms the timer, sets the system profile, and runs `switch`.
6. Commits `nixctl: <message>`.

## R7 Files to install

Replace `HOST` and the `my.*` values with the machine's real ones. Keep the inputs, `system` and `specialArgs` the existing flake already has.

`flake.nix`:
```nix
{
  description = "NixOS config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs =
    inputs@{ nixpkgs, ... }:
    let
      # Every computer = hosts/NAME/ plus all of modules/.
      mkHost =
        name:
        nixpkgs.lib.nixosSystem {
          specialArgs = { inherit inputs; };
          modules = [
            ./hosts/${name}
            ./modules
          ];
        };
    in
    {
      nixosConfigurations.nixos = mkHost "nixos";
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt;
    };
}
```

`modules/default.nix`:
```nix
# Imports every .nix file under modules/. A new module is just a new file.
{ lib, ... }:
{
  imports = builtins.filter (f: lib.hasSuffix ".nix" (toString f) && baseNameOf f != "default.nix") (
    lib.filesystem.listFilesRecursive ./.
  );
}
```

`modules/core/settings.nix`:
```nix
# Shared values any module can read, such as config.my.user.
{ lib, ... }:
{
  options.my.user = lib.mkOption {
    type = lib.types.str;
    description = "Main login user of this computer.";
  };
}
```

`modules/core/nix.nix`:
```nix
# Nix itself: flakes and unfree packages.
{ ... }:
{
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;
}
```

`modules/core/boot.nix`:
```nix
# Boot loader and kernel.
{ ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
}
```

`modules/core/system.nix`:
```nix
# Basics every computer gets: time zone, language, logs, memory.
{ ... }:
{
  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";
}
```

`modules/core/nixctl.nix`:
```nix
# nixctl, the one command for changing this computer (script: tools/nixctl.sh).
{ config, pkgs, ... }:
let
  nixctl = pkgs.writeShellApplication {
    name = "nixctl";
    runtimeInputs = with pkgs; [
      config.nix.package
      coreutils
      diffutils
      findutils
      gawk
      git
      gnugrep
      gnused
      jq
      systemd
      util-linux
    ];
    text = builtins.readFile ../../tools/nixctl.sh;
  };
in
{
  environment.systemPackages = [ nixctl ];

  # nixctl applies changes without a password prompt, so an agent can use
  # it unattended. Anything that can run commands as this user can change
  # the whole system through it.
  security.sudo.extraRules = [
    {
      users = [ config.my.user ];
      commands = [
        {
          command = "/run/current-system/sw/bin/nixctl";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];
}
```

`hosts/HOST/default.nix`:
```nix
# Control panel for the computer "nixos": which modules are on, plus
# settings that belong to this machine only.
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./packages.nix
  ];

  networking.hostName = "nixos";
  my.user = "rileyt";

  # nixctl: modules (one line per module that is on; nixctl enable/disable edit these lines)

  # Set once at install. Never change it.
  system.stateVersion = "26.05";
}
```

`hosts/HOST/packages.nix`:
```nix
# Programs installed by name. One plain name per line, sorted.
# Change with: nixctl pkg add NAME / nixctl pkg remove NAME
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    git
    htop
  ];
}
```

`.gitignore`:
```
result
result-*
```

`AGENTS.md` (repo root):
```markdown
# NixOS config
Change this computer only with `nixctl` (run `nixctl help`). Start with `nixctl map`.
Use the nixos-managing skill. Every nixctl output ends with RESULT: and usually NEXT: lines; do what NEXT says.
Never run nixos-rebuild or sudo yourself.
```

<!-- BEGIN tools/nixctl.sh -->
```bash
#!/usr/bin/env bash
# nixctl: the one command for changing this NixOS computer.
# Lives in the config repo as tools/nixctl.sh. modules/core/nixctl.nix
# installs it. Every command ends with a RESULT: line, and usually a
# NEXT: line that says what to do next.
set -euo pipefail

NIXCTL_VERSION=1
SELF=/run/current-system/sw/bin/nixctl

say() { printf '%s\n' "$*"; }
ok() {
  say "RESULT: OK $1"
  if [[ -n ${2:-} ]]; then say "NEXT: $2"; fi
  exit 0
}
fail() {
  say "RESULT: FAIL $1"
  if [[ -n ${2:-} ]]; then say "NEXT: $2"; fi
  exit 1
}

# ---------------------------------------------------------------------------
# Root part. Runs through `sudo nixctl _root ...`. sudo clears the
# environment, so this part takes only explicit arguments and never reads
# the repo.
# ---------------------------------------------------------------------------

store_system_ok() {
  [[ $1 =~ ^/nix/store/[a-z0-9]{32}-nixos-system-[^/]+$ && -x $1/bin/switch-to-configuration ]]
}

# switch-to-configuration runs in its own systemd unit, the way
# nixos-rebuild does it, so a restarted desktop or terminal cannot kill it
# halfway through.
run_stc() {
  systemd-run -E LOCALE_ARCHIVE -E NIXOS_INSTALL_BOOTLOADER -E NIXOS_NO_CHECK --collect \
    --no-ask-password --pipe --quiet --service-type=exec \
    --unit=nixctl-switch-to-configuration -- "$1/bin/switch-to-configuration" "$2"
}

bad_units() {
  systemctl list-units --state=failed,auto-restart --plain --no-legend --no-pager 2>/dev/null |
    awk '{print $1}' | sort -u || true
}

settle() {
  local _
  for _ in $(seq 1 60); do
    [[ -z $(systemctl list-jobs --no-legend 2>/dev/null) ]] && break
    sleep 1
  done
  # A service that crashes a few seconds after it starts shows up here.
  sleep 8
}

disarm() {
  systemctl stop nixctl-revert.timer >/dev/null 2>&1 || true
  systemctl reset-failed nixctl-revert.service nixctl-revert.timer >/dev/null 2>&1 || true
}

root_apply_system() {
  local new=$1 old before after newbad u
  store_system_ok "$new" || fail "not a NixOS system path: $new"
  old=$(readlink -f /run/current-system)
  before=$(bad_units)

  # Dead-man switch: if this script dies before it finishes, the old
  # system comes back by itself after 5 minutes.
  disarm
  systemd-run --quiet --unit=nixctl-revert --on-active=300 \
    --timer-property=AccuracySec=5s "$old/bin/switch-to-configuration" test

  say "== test: activating the new system (not permanent yet)"
  if ! run_stc "$new" test; then
    say "== activation reported errors, going back to the old system"
    run_stc "$old" test || true
    disarm
    say "ROLLED BACK"
    return 1
  fi

  say "== health check: waiting for services to settle"
  settle
  after=$(bad_units)
  newbad=$(comm -13 <(printf '%s\n' "$before") <(printf '%s\n' "$after") | sed '/^$/d')
  if [[ -n $newbad ]]; then
    say "== these services broke after the change:"
    for u in $newbad; do
      say "-- $u (last log lines)"
      journalctl -u "$u" -b --no-pager -n 15 -o cat 2>/dev/null || true
    done
    say "== going back to the old system"
    run_stc "$old" test || true
    disarm
    say "BROKEN UNITS: $(tr '\n' ' ' <<<"$newbad")"
    say "ROLLED BACK"
    return 1
  fi

  say "== healthy, making it permanent"
  disarm
  nix-env -p /nix/var/nix/profiles/system --set "$new"
  run_stc "$new" switch
  say "SWITCHED"
}

root_rollback() {
  nix-env -p /nix/var/nix/profiles/system --rollback
  run_stc "$(readlink -f /nix/var/nix/profiles/system)" switch
  say "SWITCHED"
}

root_clean() {
  local keep=$1
  [[ $keep =~ ^[0-9]+$ && $keep -ge 2 ]] || fail "keep must be a number of 2 or more"
  nix-env -p /nix/var/nix/profiles/system --delete-generations "+$keep"
  nix-collect-garbage
  # Rewrites the boot menu so deleted generations disappear from it.
  run_stc "$(readlink -f /nix/var/nix/profiles/system)" boot
}

if [[ ${1:-} == _root ]]; then
  [[ $EUID -eq 0 ]] || fail "_root must run as root"
  shift
  exec 9>/run/nixctl.lock
  flock -n 9 || fail "another nixctl is running" "wait a minute, then try again"
  case ${1:-} in
    apply-system) root_apply_system "${2:?}" ;;
    rollback) root_rollback ;;
    clean) root_clean "${2:-5}" ;;
    *) fail "unknown root action" ;;
  esac
  exit $?
fi

# ---------------------------------------------------------------------------
# User part. Runs as the normal user inside the config repo.
# ---------------------------------------------------------------------------

REPO=${NIXCTL_REPO:-/etc/nixos}
HOST=${NIXCTL_HOST:-$(hostname)}
SIM=${NIXCTL_SIMULATE:-0}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/nixctl
LOG=$STATE/last.log
HOSTFILE=hosts/$HOST/default.nix
PKGFILE=hosts/$HOST/packages.nix
FLAKE_ATTR=".#nixosConfigurations.$HOST"

mkdir -p "$STATE"
cd "$REPO" 2>/dev/null || fail "config repo $REPO not found" "set NIXCTL_REPO to the repo folder"
[[ -f $HOSTFILE ]] || fail "no $HOSTFILE in $REPO" "this repo is not in the nixctl layout yet; ask Claude to run the nixos-managing setup"

lock() {
  exec 8>"$STATE/lock"
  flock -n 8 || fail "another nixctl is running" "wait a minute, then try again"
}

as_root() {
  if [[ $SIM == 1 ]]; then
    say "(simulated) sudo nixctl _root $*"
    if [[ $1 == apply-system && -n ${NIXCTL_SIMULATE_FAIL_UNIT:-} ]]; then
      say "== these services broke after the change:"
      say "-- $NIXCTL_SIMULATE_FAIL_UNIT (last log lines)"
      say "(simulated) $NIXCTL_SIMULATE_FAIL_UNIT: Main process exited, code=exited, status=1/FAILURE"
      say "BROKEN UNITS: $NIXCTL_SIMULATE_FAIL_UNIT"
      say "ROLLED BACK"
      return 1
    fi
    say "SWITCHED"
    return 0
  fi
  sudo --non-interactive "$SELF" _root "$@"
}

git_q() { git -C "$REPO" "$@"; }

commit() {
  local msg=$1
  git_q add -A
  if git_q diff --cached --quiet; then return 0; fi
  if [[ -z $(git_q config user.email || true) ]]; then
    git_q -c user.name=nixctl -c user.email=nixctl@localhost commit -q -m "nixctl: $msg"
  else
    git_q commit -q -m "nixctl: $msg"
  fi
  say "== saved in git: nixctl: $msg"
}

# Turns a Nix error log into: the error line, the code around it, the repo
# file and line, and a hint for the NEXT: line (in HINT).
HINT=""
explain_nix_error() {
  local log=$1 msg loc="" f l opt
  msg=$(grep -E '^[[:space:]]*error:' "$log" | sed -E 's/^[[:space:]]*error:[[:space:]]*//' | grep -v '^$' | tail -1)
  [[ -n $msg ]] || msg=$(grep -vE '^[[:space:]]*$' "$log" | tail -1)
  while IFS= read -r l; do
    f=${l%%:*}
    if [[ -f $REPO/$f ]]; then loc=$l; fi
  done < <(grep -oE '(/nix/store/[a-z0-9]{32}-source|'"$REPO"')/[^:[:space:]'"'"'`]+\.nix(:[0-9]+:[0-9]+)?' "$log" |
    sed -E 's#^/nix/store/[a-z0-9]{32}-source/##; s#^'"$REPO"'/##')
  say "ERROR: $msg"
  # The numbered code lines Nix prints under the last error.
  awk '/^[[:space:]]*error:/ {buf = ""; n = 0; next} /^[[:space:]]+[0-9]+\|/ && n < 4 {buf = buf $0 "\n"; n++} END {printf "%s", buf}' "$log"
  if [[ -n $loc ]]; then say "WHERE: $loc"; fi
  HINT="fix the file and line in WHERE, then run nixctl check"
  if [[ $msg =~ The\ option\ .([A-Za-z0-9_.\<\>-]+).\ does\ not\ exist ]]; then
    opt=${BASH_REMATCH[1]}
    HINT="that option name is wrong; run nixctl option ${opt%.*} to see the real names, fix ${loc:-the module}, then nixctl check"
  elif [[ $msg == *"undefined variable"* ]]; then
    HINT="a word in ${loc:-the module} is misspelled or not defined; fix it, then nixctl check"
  elif [[ $msg == *"is not of type"* ]]; then
    HINT="wrong kind of value; run nixctl option NAME to see the type it needs, fix ${loc:-the module}, then nixctl check"
  elif [[ $msg == *"syntax error"* ]]; then
    HINT="broken Nix syntax (often a missing ; or }) at WHERE; fix it, then nixctl check"
  elif [[ $msg == *"does not exist"* && $msg == *"path"* ]]; then
    HINT="a file is missing or not added to git; check the path, then nixctl check"
  fi
}

guards() {
  local changed added
  changed=$(git_q diff HEAD --name-only; git_q ls-files --others --exclude-standard)
  if grep -qE '(^|/)hardware-configuration\.nix$' <<<"$changed" && [[ ${NIXCTL_ALLOW_HARDWARE:-0} != 1 ]]; then
    fail "hardware-configuration.nix was changed; it must stay as generated" "run: git -C $REPO checkout HEAD -- $(grep -E 'hardware-configuration\.nix$' <<<"$changed" | head -1)"
  fi
  if grep -qE '^secrets/' <<<"$changed" && [[ ${NIXCTL_ALLOW_SECRETS:-0} != 1 ]]; then
    fail "files in secrets/ were changed; only Riley changes secrets" "run: nixctl undo"
  fi
  if grep -qE '^flake\.lock$' <<<"$changed" && [[ ${NIXCTL_ALLOW_LOCK:-0} != 1 ]]; then
    fail "flake.lock was changed by hand" "run: git -C $REPO checkout HEAD -- flake.lock, then use nixctl update"
  fi
  added=$(git_q diff HEAD -U0 -- '*.nix' | grep -E '^\+[^+]' || true)
  if grep -qE 'stateVersion' <<<"$added"; then
    fail "a stateVersion line was changed; it must never change" "put the old stateVersion line back, then run nixctl apply again"
  fi
  if grep -iE '(password|passwd|secret|token|api_?key)[A-Za-z_]*[[:space:]]*=[[:space:]]*"[^"]+"' <<<"$added" |
    grep -viE '(file|path|dir)[[:space:]]*=' | grep -q .; then
    fail "a password, token or key looks like it was written into a .nix file" "remove it; secrets go in secrets/ with agenix (ask Riley)"
  fi
}

format_changed() {
  local files
  files=$( (git_q diff HEAD --name-only --diff-filter=AM; git_q ls-files --others --exclude-standard) | grep -E '\.nix$' | sort -u || true)
  [[ -n $files ]] || return 0
  # shellcheck disable=SC2086
  nix fmt -- $files >/dev/null 2>&1 || true
}

eval_drv() {
  nix eval --raw "$FLAKE_ATTR.config.system.build.toplevel.drvPath" >"$STATE/drv" 2>"$LOG"
}

cmd_check() {
  lock
  git_q add -A
  guards
  format_changed
  git_q add -A
  say "== evaluating the config"
  if ! eval_drv; then
    explain_nix_error "$LOG"
    fail "the config has an error" "$HINT"
  fi
  ok "the config evaluates (nothing built or changed yet)" "nixctl apply \"short description of the change\""
}

cmd_apply() {
  local msg=${1:-} new start
  [[ -n $msg ]] || fail "apply needs a message" "nixctl apply \"what you changed\""
  lock
  start=$SECONDS
  git_q add -A
  guards
  format_changed
  git_q add -A

  say "== 1/3 evaluate"
  if ! eval_drv; then
    explain_nix_error "$LOG"
    fail "the config has an error, nothing was changed" "$HINT"
  fi

  say "== 2/3 build (can take several minutes; wait for it)"
  if [[ $SIM == 1 ]]; then
    new="(simulated) $(cat "$STATE/drv")"
    say "(simulated) build of $(cat "$STATE/drv")"
  else
    if ! new=$(nix build --no-link --print-out-paths "$FLAKE_ATTR.config.system.build.toplevel" 2>"$LOG"); then
      explain_nix_error "$LOG"
      fail "the build failed, nothing was changed (full log: $LOG)" "read ERROR; if it names a file in this repo fix it, otherwise run nixctl undo and report ERROR"
    fi
    if [[ $new == "$(readlink -f /run/current-system)" ]]; then
      commit "$msg"
      ok "no change to the running system (files saved)" ""
    fi
    say "== what changes:"
    nix store diff-closures /run/current-system "$new" 2>/dev/null | head -25 || true
  fi

  say "== 3/3 test, health check, switch"
  if ! as_root apply-system "$new" | tee -a "$LOG"; then
    fail "the new system broke something and was rolled back; your file edits are still there" "read the log lines above, run nixctl logs UNIT for more, fix the module, then nixctl apply again (or nixctl undo)"
  fi
  commit "$msg"
  ok "applied in $((SECONDS - start))s: $msg" "if something looks wrong later: nixctl rollback"
}

cmd_undo() {
  lock
  if git_q diff HEAD --quiet && [[ -z $(git_q ls-files --others --exclude-standard) ]]; then
    ok "nothing to undo; files already match the last saved version"
  fi
  git_q stash push --include-untracked -q -m "nixctl undo $(date -Is)"
  ok "unsaved edits removed (kept in git stash; Riley can get them back with git stash pop)" "nixctl status"
}

cmd_rollback() {
  lock
  if ! as_root rollback; then
    fail "rollback failed" "run nixctl status and report the output"
  fi
  if git_q log -1 --format=%s | grep -q '^nixctl: '; then
    git_q revert --no-edit HEAD >/dev/null
    say "== files reverted to match (git revert of the last nixctl change)"
  fi
  ok "the computer is back on the previous version" "nixctl status"
}

cmd_status() {
  local gen
  say "== running system"
  if [[ $SIM == 1 ]]; then
    say "(simulated) generation 42, running"
  else
    gen=$(readlink /nix/var/nix/profiles/system || true)
    say "profile: ${gen:-unknown}"
    say "running: $(readlink -f /run/current-system)"
  fi
  say "== unsaved file edits"
  git_q status --short | head -20
  [[ -n $(git_q status --short) ]] || say "(none)"
  say "== broken services"
  local bad
  bad=$(bad_units)
  if [[ -n ${NIXCTL_SIMULATE_FAIL_UNIT:-} ]]; then bad=$NIXCTL_SIMULATE_FAIL_UNIT; fi
  say "${bad:-(none)}"
  say "== disk"
  df -h --output=target,size,avail,pcent /nix/store /boot 2>/dev/null | awk '!seen[$1]++' || true
  say "== last saved changes"
  git_q log -5 --format='%h %ar  %s'
  if [[ -n $bad ]]; then
    ok "status shown; some services are broken" "nixctl logs $(head -1 <<<"$bad")"
  fi
  ok "status shown"
}

cmd_logs() {
  local unit=${1:-}
  [[ -n $unit ]] || fail "logs needs a unit name" "nixctl status (to see broken services)"
  [[ $unit == *.* ]] || unit=$unit.service
  journalctl -u "$unit" -b --no-pager -n 60 -o short-iso 2>&1 || true
  ok "last 60 log lines for $unit this boot" "nixctl map (to find the module for $unit)"
}

module_option() { # modules/services/foo.nix -> my.services.foo
  local p=${1#modules/}
  p=${p%.nix}
  say "my.${p//\//.}"
}

cmd_map() {
  local f opt desc state n
  say "Control panel: $HOSTFILE (which modules are on)"
  say "Programs list: $PKGFILE"
  say ""
  printf '%-28s %-7s %s\n' "MODULE" "STATE" "WHAT IT DOES"
  while IFS= read -r f; do
    [[ $(basename "$f") == default.nix ]] && continue
    opt=$(module_option "$f")
    desc=$(head -1 "$f" | sed -E 's/^#[[:space:]]*//')
    if [[ $f == modules/core/* ]]; then
      state=always
    elif grep -qE "^[[:space:]]*${opt//./\\.}\.enable[[:space:]]*=[[:space:]]*true;" "$HOSTFILE"; then
      state=on
    else
      state=off
    fi
    f=${f#modules/}
    printf '%-28s %-7s %s\n' "${f%.nix}" "$state" "$desc"
  done < <(find modules -name '*.nix' | sort)
  n=$(pkg_lines | wc -l)
  say ""
  say "Programs installed by name: $n (see $PKGFILE)"
  ok "map shown" "edit a module file, or use nixctl enable/disable/pkg"
}

cmd_new() {
  local name=${1:-} desc=${2:-} file opt
  [[ $name =~ ^[a-z0-9-]+/[a-z0-9][a-z0-9-]*$ ]] || fail "name must look like GROUP/NAME, e.g. services/jellyfin" "nixctl new services/NAME \"what it does\""
  [[ $name != core/* ]] || fail "core modules are made by Claude, not with nixctl new" "pick another group, e.g. services/ or apps/"
  [[ -n $desc ]] || fail "new needs a one-line description" "nixctl new $name \"what it does\""
  file=modules/$name.nix
  [[ ! -e $file ]] || fail "$file already exists" "edit $file instead"
  opt=$(module_option "$file")
  mkdir -p "$(dirname "$file")"
  cat >"$file" <<EOF
# $desc
{ config, lib, pkgs, ... }:
let
  cfg = config.$opt;
in
{
  options.$opt.enable = lib.mkEnableOption "${desc%.}";

  config = lib.mkIf cfg.enable {
    # Put this module's settings here.
  };
}
EOF
  git_q add "$file"
  ok "created $file (off until enabled)" "edit the settings inside config = lib.mkIf cfg.enable { ... }, then nixctl enable $name, then nixctl apply \"add $name\""
}

enable_line_re() { # regex for the enable line of a module option
  say "^[[:space:]]*${1//./\\.}\.enable[[:space:]]*=[[:space:]]*(true|false);"
}

cmd_enable() {
  local name=${1:-} file opt tmp
  file=modules/$name.nix
  [[ -n $name && -f $file ]] || fail "no module $file" "nixctl map (to see module names)"
  [[ $name != core/* ]] || ok "$name is a core module; it is always on"
  opt=$(module_option "$file")
  if grep -qE "$(enable_line_re "$opt")" "$HOSTFILE"; then
    sed -i -E "s#^([[:space:]]*)${opt//./\\.}\.enable[[:space:]]*=[[:space:]]*false;#\1$opt.enable = true;#" "$HOSTFILE"
  else
    grep -q '^[[:space:]]*# nixctl: modules' "$HOSTFILE" || fail "$HOSTFILE has no '# nixctl: modules' marker line" "ask Claude to fix the control panel layout"
    tmp=$(mktemp)
    awk -v line="  $opt.enable = true;" '
      { print }
      /^[[:space:]]*# nixctl: modules/ { print line }
    ' "$HOSTFILE" >"$tmp" && cat "$tmp" >"$HOSTFILE" && rm -f "$tmp"
    sort_enable_block
  fi
  ok "$name is set to on (not applied yet)" "nixctl apply \"enable $name\""
}

cmd_disable() {
  local name=${1:-} file opt
  file=modules/$name.nix
  [[ -n $name && -f $file ]] || fail "no module $file" "nixctl map (to see module names)"
  [[ $name != core/* ]] || fail "$name is a core module and cannot be turned off" "nixctl map"
  opt=$(module_option "$file")
  sed -i -E "/$(enable_line_re "$opt")/d" "$HOSTFILE"
  ok "$name is set to off (not applied yet)" "nixctl apply \"disable $name\""
}

# Keeps the lines right under the marker sorted, so the control panel
# reads like a menu.
sort_enable_block() {
  local tmp
  tmp=$(mktemp)
  awk '
    function flush(   i, j, t) {
      for (i = 2; i <= n; i++) { t = buf[i]; j = i - 1; while (j >= 1 && buf[j] > t) { buf[j + 1] = buf[j]; j-- } buf[j + 1] = t }
      for (i = 1; i <= n; i++) if (i == 1 || buf[i] != buf[i - 1]) print buf[i]
      n = 0
    }
    inblock && /^[[:space:]]*my\.[A-Za-z0-9.-]+\.enable = true;[[:space:]]*$/ { buf[++n] = $0; next }
    inblock { flush(); inblock = 0 }
    /^[[:space:]]*# nixctl: modules/ { print; inblock = 1; next }
    { print }
    END { flush() }
  ' "$HOSTFILE" >"$tmp" && cat "$tmp" >"$HOSTFILE" && rm -f "$tmp"
}

pkg_lines() {
  awk '/environment\.systemPackages = with pkgs; \[/ {inl=1; next} inl && /^[[:space:]]*\];/ {inl=0} inl {gsub(/^[[:space:]]+|[[:space:]]+$/, ""); if ($0 != "") print}' "$PKGFILE"
}

write_pkgs() { # stdin: names
  local tmp
  tmp=$(mktemp)
  sort -fu >"$tmp.names"
  awk -v names="$tmp.names" '
    /environment\.systemPackages = with pkgs; \[/ { print; while ((getline n < names) > 0) print "    " n; skip=1; next }
    skip && /^[[:space:]]*\];/ { skip=0 }
    skip { next }
    { print }
  ' "$PKGFILE" >"$tmp" && cat "$tmp" >"$PKGFILE"
  rm -f "$tmp" "$tmp.names"
}

cmd_pkg() {
  local action=${1:-} name have
  shift || true
  [[ $action == add || $action == remove ]] || fail "use: nixctl pkg add NAME or nixctl pkg remove NAME"
  [[ $# -gt 0 ]] || fail "pkg $action needs a package name" "nixctl search WORD (to find the exact name)"
  have=$(pkg_lines)
  if grep -vqE '^[A-Za-z0-9_.+-]+$' <<<"$have"; then
    fail "$PKGFILE has a line that is not a plain package name" "move that line into a module (ask Claude), then try again"
  fi
  for name in "$@"; do
    [[ $name =~ ^[A-Za-z0-9_.+-]+$ ]] || fail "bad package name: $name"
    if [[ $action == add ]]; then
      if grep -qxF "$name" <<<"$have"; then say "== $name is already in the list"; continue; fi
      if ! nix eval --raw "$FLAKE_ATTR.pkgs.$name.name" >/dev/null 2>"$LOG"; then
        fail "there is no package called $name" "nixctl search $name"
      fi
      have=$(printf '%s\n%s\n' "$have" "$name")
      say "== added $name"
    else
      if ! grep -qxF "$name" <<<"$have"; then
        fail "$name is not in $PKGFILE (it may come from a module)" "nixctl map, then look for $name in the module files"
      fi
      have=$(grep -vxF "$name" <<<"$have" || true)
      say "== removed $name"
    fi
  done
  sed '/^$/d' <<<"$have" | write_pkgs
  git_q add "$PKGFILE"
  ok "programs list updated (not applied yet)" "nixctl apply \"$action $*\""
}

cmd_search() {
  local word=${1:-} src exact
  [[ -n $word ]] || fail "search needs a word" "nixctl search firefox"
  # Fast path: the word is already an exact package name (about 2 seconds).
  # shellcheck disable=SC2016
  if exact=$(nix eval --raw "$FLAKE_ATTR.pkgs.$word" --apply 'p: "${p.name}  ${p.meta.description or ""}"' 2>/dev/null); then
    say "exact match: $word  ($exact)"
    ok "$word is a package" "nixctl pkg add $word"
  fi
  src=$(nix eval --raw "$FLAKE_ATTR.pkgs.path" 2>"$LOG") || { explain_nix_error "$LOG"; fail "could not read nixpkgs"; }
  say "== no exact match; searching all packages for '$word' (first 15; the first search can take a few minutes)"
  NIXPKGS_ALLOW_UNFREE=1 nix search --impure --json "path:$src" "$word" 2>"$LOG" |
    jq -r 'to_entries | sort_by(.key | length) | .[:15][] | "\(.key | sub("^legacyPackages\\.[^.]+\\."; ""))  \(.value.version)  \(.value.description)"' || true
  ok "search done" "nixctl pkg add NAME (use the exact name from the first column)"
}

cmd_option() {
  local path=${1:-} expr
  [[ $path =~ ^[A-Za-z0-9_.\<\>*-]+$ ]] || fail "option needs a name like services.jellyfin.enable" "nixctl option services.jellyfin"
  expr=$(
    cat <<'EOF'
opts: let
  path = builtins.filter (s: builtins.isString s && s != "") (builtins.split "\\." "OPTPATH");
  isOpt = x: builtins.isAttrs x && (x._type or null) == "option";
  isDrv = x: builtins.isAttrs x && (x.type or null) == "derivation";
  take = n: l: if n == 0 || l == [] then [] else [ (builtins.head l) ] ++ take (n - 1) (builtins.tail l);
  san = d: v:
    if builtins.isFunction v then "<function>"
    else if isDrv v then "<package ${v.name or "?"}>"
    else if builtins.isPath v then toString v
    else if builtins.isAttrs v then (if d > 2 then "<set>" else builtins.mapAttrs (_: san (d + 1)) v)
    else if builtins.isList v then (if d > 2 then "<list>" else map (san (d + 1)) (take 20 v))
    else v;
  safe = v: let r = builtins.tryEval (let s = san 0 v; in builtins.deepSeq s s); in if r.success then r.value else "<not set>";
  text = v: if builtins.isAttrs v then (v.text or "") else toString v;
  walk = cur: rest:
    if rest == [] then cur
    else if isOpt cur then
      (let sub = builtins.tryEval (cur.type.getSubOptions [ ]); in
       if sub.success && sub.value != { } then
         walk sub.value (if builtins.elem (builtins.head rest) [ "<name>" "*" ] then builtins.tail rest else rest)
       else null)
    else if builtins.isAttrs cur && builtins.hasAttr (builtins.head rest) cur then walk cur.${builtins.head rest} (builtins.tail rest)
    else null;
  o = walk opts path;
  # Deepest part of the path that does exist, and close names inside it.
  prefixes = builtins.genList (i: take (builtins.length path - 1 - i) path) (builtins.length path);
  nearest = let hits = builtins.filter (p: p == [ ] || walk opts p != null) prefixes; in if hits == [ ] then [ ] else builtins.head hits;
  nearSet = if nearest == [ ] then opts else walk opts nearest;
  missing = builtins.elemAt path (builtins.length nearest);
  close = if isOpt nearSet || !(builtins.isAttrs nearSet) then [ ] else
    take 8 (builtins.filter (n: builtins.substring 0 3 n == builtins.substring 0 3 missing) (builtins.attrNames nearSet));
  join = l: builtins.concatStringsSep "." l;
in
  if o == null then { exists = false; nearest = join nearest; inherit close; }
  else if !(isOpt o) then { exists = true; kind = "group"; children = builtins.attrNames o; }
  else {
    exists = true;
    kind = "option";
    type = o.type.description or "unknown";
    description = text (o.description or "");
    default = if o ? defaultText then text o.defaultText else if o ? default then safe o.default else "<no default>";
    current = safe o.value;
    example = if o ? example then (if builtins.isAttrs o.example && o.example ? text then o.example.text else safe o.example) else null;
  }
EOF
  )
  expr=${expr//OPTPATH/$path}
  if ! nix eval --json "$FLAKE_ATTR.options" --apply "$expr" >"$STATE/option.json" 2>"$LOG"; then
    explain_nix_error "$LOG"
    fail "could not read options (the config may have an error)" "nixctl check"
  fi
  if [[ $(jq -r .exists "$STATE/option.json") != true ]]; then
    local near close
    near=$(jq -r .nearest "$STATE/option.json")
    close=$(jq -r '.close | join(", ")' "$STATE/option.json")
    [[ -z $close ]] || say "Did you mean one of these (inside ${near:-the top level}): $close"
    fail "option $path does not exist; do not use it" "nixctl option ${near:-services} (to list what exists there)"
  fi
  if [[ $(jq -r .kind "$STATE/option.json") == group ]]; then
    say "$path contains:"
    jq -r '.children | join("  ")' "$STATE/option.json" | fold -s -w 100
    ok "$path is a group of options" "nixctl option $path.NAME (pick one from the list)"
  fi
  jq -r '"name: '"$path"'\ntype: \(.type)\ndefault: \(.default | if type == "string" then . else tojson end)\ncurrent value: \(.current | tojson)\n" + (if .example then "example: \(.example | if type == "string" then . else tojson end)\n" else "" end) + "description: \(.description | .[0:600])"' "$STATE/option.json"
  ok "option $path exists" "set it inside a module's config block, then nixctl apply"
}

cmd_update() {
  local input=${1:-}
  lock
  if [[ -n $input ]]; then nix flake update "$input" 2>"$LOG" || { explain_nix_error "$LOG"; fail "update failed"; }
  else nix flake update 2>"$LOG" || { explain_nix_error "$LOG"; fail "update failed"; }; fi
  exec 8>&-
  NIXCTL_ALLOW_LOCK=1 exec "$0" apply "update ${input:-all inputs}"
}

cmd_clean() {
  local keep=${1:-5} before after
  lock
  before=$(df -h --output=avail /nix/store | tail -1 | tr -d ' ')
  if ! as_root clean "$keep"; then fail "cleanup failed" "nixctl status"; fi
  after=$(df -h --output=avail /nix/store | tail -1 | tr -d ' ')
  ok "kept the newest $keep system versions and deleted unused files; free space $before -> $after" ""
}

cmd_audit() {
  local facts n=0
  say "== reading settings (one evaluation)"
  if ! facts=$(nix eval --json "$FLAKE_ATTR.config" --apply '
    c: {
      gc = c.nix.gc.automatic;
      optimise = c.nix.optimise.automatic || (c.nix.settings.auto-optimise-store or false);
      bootLimit = c.boot.loader.systemd-boot.configurationLimit;
      systemdBoot = c.boot.loader.systemd-boot.enable;
      zram = c.zramSwap.enable;
      fstrim = c.services.fstrim.enable;
      docs = c.documentation.nixos.enable;
      journal = c.services.journald.extraConfig;
      waitOnline = c.systemd.services.NetworkManager-wait-online.enable or false;
      nm = c.networking.networkmanager.enable;
      jobs = c.nix.settings.max-jobs or "auto";
      minFree = c.nix.settings.min-free or null;
    }' 2>"$LOG"); then
    explain_nix_error "$LOG"
    fail "could not read the config" "nixctl check"
  fi
  finding() {
    n=$((n + 1))
    say "$n. [$1] $2"
    say "   FIX: $3"
  }
  [[ $(jq -r .gc <<<"$facts") == true ]] || finding disk "Old system versions are never deleted automatically." "in modules/core/nix.nix set: nix.gc = { automatic = true; dates = \"weekly\"; options = \"--delete-older-than 14d\"; };"
  [[ $(jq -r .optimise <<<"$facts") == true ]] || finding disk "Identical files in /nix/store are not merged." "in modules/core/nix.nix set: nix.optimise.automatic = true;"
  if [[ $(jq -r .systemdBoot <<<"$facts") == true && $(jq -r .bootLimit <<<"$facts") == null ]]; then
    finding disk "The boot menu keeps every version, so /boot can fill up." "in modules/core/boot.nix set: boot.loader.systemd-boot.configurationLimit = 10;"
  fi
  [[ $(jq -r .minFree <<<"$facts") != null ]] || finding disk "Nothing frees space when the disk gets nearly full." "in modules/core/nix.nix set: nix.settings.min-free = 5 * 1024 * 1024 * 1024;"
  grep -q SystemMaxUse <<<"$(jq -r .journal <<<"$facts")" || finding disk "System logs can grow to 4 GB." "in modules/core/system.nix set: services.journald.extraConfig = \"SystemMaxUse=500M\";"
  [[ $(jq -r .zram <<<"$facts") == true ]] || finding speed "No compressed RAM swap, so heavy jobs hit the disk sooner." "in modules/core/system.nix set: zramSwap.enable = true;"
  [[ $(jq -r .fstrim <<<"$facts") == true ]] || finding speed "SSD trim is off." "in modules/core/system.nix set: services.fstrim.enable = true;"
  if [[ $(jq -r .nm <<<"$facts") == true && $(jq -r .waitOnline <<<"$facts") == true ]]; then
    finding speed "Boot waits for the network to be fully online." "check first with: systemd-analyze blame | head; if NetworkManager-wait-online is near the top, set in modules/core/network.nix: systemd.services.NetworkManager-wait-online.enable = false; (skip if a service needs the network at boot)"
  fi
  [[ $(jq -r .docs <<<"$facts") == false ]] || finding rebuild "Every rebuild regenerates the NixOS options manual." "optional, saves rebuild time: in modules/core/nix.nix set documentation.nixos.enable = false; (removes man configuration.nix; nixctl option still works)"

  # Layout checks: text only, no evaluation.
  local f opt stray dupes
  while IFS= read -r f; do
    [[ $(basename "$f") == default.nix ]] && continue
    head -1 "$f" | grep -q '^#' || finding layout "$f has no one-line description on line 1." "add a comment like '# What this module does' as the first line"
    if [[ $f != modules/core/* ]]; then
      opt=$(module_option "$f")
      grep -qF "options.$opt" "$f" || finding layout "$f does not declare options.$opt.enable." "use the module shape from the skill (nixctl new makes it)"
    fi
  done < <(find modules -name '*.nix' | sort)
  stray=$(find . -maxdepth 1 -type f -name '*.nix' ! -name flake.nix | sed 's#^\./##' || true)
  [[ -z $stray ]] || finding layout "Loose .nix files at the top of the repo: $(tr '\n' ' ' <<<"$stray")" "move each into modules/GROUP/ (needs Claude)"
  # shellcheck disable=SC2016
  dupes=$(find modules hosts -name '*.nix' -print0 | xargs -0 awk '
    { gsub(/^[[:space:]]+/, ""); line[FNR] = $0 }
    FNR >= 3 && line[FNR] != "" && line[FNR-1] != "" && line[FNR-2] != "" && line[FNR] !~ /^[]})];?$/ {
      k = line[FNR-2] "\n" line[FNR-1] "\n" line[FNR]; if (!(k in seen)) seen[k] = FILENAME; c[k]++ }
    END { for (k in c) if (c[k] >= 3) { split(k, p, "\n"); printf "%dx in %s: %s\n", c[k], seen[k], p[1] } }' | sort -rn | head -3 || true)
  if [[ -n $dupes ]]; then
    while IFS= read -r f; do finding duplicate "The same 3 lines repeat $f" "fold the copies into one loop (lib.genAttrs or a list); needs Claude"; done <<<"$dupes"
  fi
  if [[ $SIM != 1 ]]; then
    say "== disk now"
    df -h --output=target,size,avail,pcent /nix/store /boot 2>/dev/null | awk '!seen[$1]++' || true
    say "system versions kept: $(find /nix/var/nix/profiles -maxdepth 1 -name 'system-*-link' | wc -l)"
  fi
  if [[ $n -eq 0 ]]; then ok "no findings"; fi
  ok "$n findings" "do one FIX at a time and run nixctl apply after each; findings marked 'needs Claude' are for a bigger model"
}

cmd_help() {
  cat <<'EOF'
nixctl: change this NixOS computer safely. Run from anywhere.

Look:
  nixctl map                      every module, on/off, and what it does
  nixctl status                   running version, unsaved edits, broken services, disk
  nixctl search WORD              find a package name
  nixctl option NAME              check an option exists, its type, default, current value
  nixctl logs UNIT                last log lines of a service
Change files (nothing happens until apply):
  nixctl pkg add NAME...          add programs to hosts/HOST/packages.nix
  nixctl pkg remove NAME...       remove programs from that list
  nixctl new GROUP/NAME "what"    make a new module file (off until enabled)
  nixctl enable GROUP/NAME        turn a module on
  nixctl disable GROUP/NAME       turn a module off
Apply:
  nixctl check                    find config errors fast, change nothing
  nixctl apply "message"          build, test, keep only if healthy, save in git
  nixctl undo                     throw away unsaved edits (kept in git stash)
  nixctl rollback                 go back to the previous system version
Upkeep:
  nixctl update [INPUT]           update nixpkgs and other inputs, then apply
  nixctl clean [KEEP]             delete old system versions (keeps 5) and unused files
  nixctl audit                    list ways to save disk, speed up, and tidy the config
EOF
  ok "help shown" "nixctl map"
}

case ${1:-help} in
  map) cmd_map ;;
  status) cmd_status ;;
  search) cmd_search "${2:-}" ;;
  option) cmd_option "${2:-}" ;;
  logs) cmd_logs "${2:-}" ;;
  pkg) shift; cmd_pkg "$@" ;;
  new) cmd_new "${2:-}" "${3:-}" ;;
  enable) cmd_enable "${2:-}" ;;
  disable) cmd_disable "${2:-}" ;;
  check) cmd_check ;;
  apply) cmd_apply "${2:-}" ;;
  undo) cmd_undo ;;
  rollback) cmd_rollback ;;
  update) cmd_update "${2:-}" ;;
  clean) cmd_clean "${2:-5}" ;;
  audit) cmd_audit ;;
  version) ok "nixctl version $NIXCTL_VERSION" ;;
  help | -h | --help) cmd_help ;;
  *) say "unknown command: $1"; cmd_help ;;
esac
```
<!-- END tools/nixctl.sh -->

`cfgdiff.sh` is used during setup only; keep it in `/tmp` or `tools/`:

<!-- BEGIN cfgdiff.sh -->
```bash
#!/usr/bin/env bash
# cfgdiff: what really differs between two NixOS system derivations.
# Usage: cfgdiff.sh OLD.drv NEW.drv
# Prints the root-cause derivations (changed, but none of their inputs
# changed) and, for each, which environment values differ. "same items,
# different order" means only list order moved, which is usually harmless.
set -uo pipefail
old=$1 new=$2
if [[ $old == "$new" ]]; then echo "IDENTICAL: the two configs build exactly the same system"; exit 0; fi
tmp=$(mktemp -d)
nix-store -qR "$old" | sort >"$tmp/old"
nix-store -qR "$new" | sort >"$tmp/new"
comm -13 "$tmp/old" "$tmp/new" >"$tmp/changed"
name() { basename "$1" | cut -d- -f2- | sed 's/\.drv$//'; }
# Works with both the old and the Nix 2.33+ JSON layout of `nix derivation show`.
drv() { nix derivation show "$1" | jq -S '(.derivations // .) | to_entries[0].value'; }
vals() { drv "$1" | jq -S '(.env // {}) + (.structuredAttrs // {}) | with_entries(.value |= (if type == "string" then . else tojson end))'; }
echo "Changed derivations: $(wc -l <"$tmp/changed")"
while IFS= read -r d; do
  ins=$(drv "$d" | jq -r '(.inputDrvs // .inputs.drvs // {}) | keys[]' 2>/dev/null | sed 's#^\([^/]\)#/nix/store/\1#')
  if [[ -n $ins ]] && grep -xFf "$tmp/changed" <<<"$ins" >/dev/null; then continue; fi
  n=$(name "$d")
  o=$(grep -F -- "-$n.drv" "$tmp/old" | grep -E "/[a-z0-9]{32}-" | while IFS= read -r x; do [[ $(name "$x") == "$n" ]] && echo "$x"; done)
  echo "== ROOT CAUSE: $n"
  if [[ -z $o ]]; then echo "   new derivation (not in the old system)"; continue; fi
  if [[ $(wc -l <<<"$o") -gt 1 ]]; then echo "   new or changed (the name '$n' is used $(wc -l <<<"$o") times in the old system, so it can't be paired)"; continue; fi
  vals "$o" >"$tmp/oe"
  vals "$d" >"$tmp/ne"
  for k in $(jq -r 'keys[]' "$tmp/oe" "$tmp/ne" | sort -u | grep -vxE 'out|outputHash'); do
    a=$(jq -r --arg k "$k" '.[$k] // ""' "$tmp/oe")
    b=$(jq -r --arg k "$k" '.[$k] // ""' "$tmp/ne")
    [[ $a == "$b" ]] && continue
    if [[ $(tr -s ' \n' '\n\n' <<<"$a" | sort) == $(tr -s ' \n' '\n\n' <<<"$b" | sort) ]]; then
      echo "   $k: same items, different order"
    else
      echo "   $k differs:"
      diff <(tr -s ' ' '\n' <<<"$a") <(tr -s ' ' '\n' <<<"$b") | grep '^[<>]' | head -8 | cut -c1-160 | sed 's/^/     /'
    fi
  done
done <"$tmp/changed"
rm -rf "$tmp"
```
<!-- END cfgdiff.sh -->
