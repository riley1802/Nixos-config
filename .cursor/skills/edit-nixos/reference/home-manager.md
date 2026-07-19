# Home Manager

- User: `rileyt`
- Entries: `home.nix` (nixos desktop), `home-legion.nix` (legion laptop); both import `home/common.nix`
- Uses global pkgs from flake (`useGlobalPkgs = true`)

## Modules

| Path | Purpose |
|------|---------|
| `home/core/identity.nix` | Username and home directory |
| `home/core/state-version.nix` | home.stateVersion |
| `home/core/home-manager.nix` | Enable Home Manager |
| `home/desktop/cursor.nix` | Pointer cursor theme |
| `home/desktop/gnome/interface.nix` | GNOME interface dconf |
| `home/desktop/gnome/extensions.nix` | GNOME shell extensions dconf |
| `home/desktop/gnome/dash-to-dock.nix` | Dash to Dock dconf |
| `home/programs/git.nix` | Git identity (user.name / user.email) |
| `home/programs/utilities.nix` | CLI utilities |
| `home/programs/google-chrome.nix` | Google Chrome |
| `home/programs/spotify.nix` | Spotify |
| `home/programs/discord.nix` | Discord |
| `home/programs/cursor.nix` | Cursor editor and CLI |
| `home/programs/claude-code.nix` | Claude Code (`pkgsUnstable.claude-code`) |

## Conventions

- Managed config files that may already exist on disk → `force = true`
- Desktop app launchers on GNOME/Wayland → prefer `kgx` (GNOME Console) over `gnome-terminal` (see lessons.md)
- One program or one dconf domain per file
