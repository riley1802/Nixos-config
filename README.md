# NixOS Config

Personal NixOS configuration for the `nixos` host and `rileyt` user.

This repository uses Nix flakes and Home Manager as a NixOS module. System
configuration lives under `modules/`, while user configuration lives under
`home/`.

## Layout

- `flake.nix` - flake inputs and the `nixos` system output.
- `configuration.nix` - top-level NixOS module imports.
- `hardware-configuration.nix` - generated hardware and filesystem settings for this machine.
- `home.nix` - top-level Home Manager imports.
- `modules/core/` - boot, locale, networking, and system defaults.
- `modules/desktop/` - GNOME and audio configuration.
- `modules/hardware/` - hardware-specific modules.
- `modules/programs/` - system-level applications and program settings.
- `modules/services/` - system services.
- `modules/users/` - local user accounts.
- `home/` - Home Manager modules for user packages and desktop preferences.

## Usage

Apply the system configuration from this repository:

```sh
sudo nixos-rebuild switch --flake .#nixos
```

Build the system without switching:

```sh
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
```

Update locked inputs:

```sh
nix flake update
sudo nixos-rebuild switch --flake .#nixos
```

Format Nix files:

```sh
nix fmt
```

## Publishing Notes

Before pushing this repository publicly, review machine-specific files:

- `hardware-configuration.nix` includes disk UUIDs and hardware details.
- `modules/core/networking.nix` includes the hostname.
- `modules/users/rileyt.nix` includes the local username and groups.
- Do not commit private keys, access tokens, age identities, or plaintext credentials.

Commit secrets only if they are encrypted with a tool such as `sops-nix` or
`agenix`, and keep the decryption keys outside the repository.
