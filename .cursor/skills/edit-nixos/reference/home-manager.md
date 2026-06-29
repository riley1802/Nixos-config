# Home Manager

- User: `rileyt`
- Entry: `home.nix`
- Uses global pkgs from flake (`useGlobalPkgs = true`)

## Modules

| Path | Purpose |
|------|---------|
| `home/core/default.nix` | Base HM config |
| `home/desktop/gnome.nix` | GNOME user settings |
| `home/programs/packages.nix` | User-level packages |

## Conventions

- Managed config files that may already exist on disk → `force = true`
- Desktop app launchers on GNOME/Wayland → prefer `kgx` (GNOME Console) over `gnome-terminal` (see lessons.md)
