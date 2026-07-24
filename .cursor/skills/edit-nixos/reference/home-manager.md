# Home Manager

- User: `rileyt`
- Entry: `home.nix` on every host (imports `home/common.nix` only)
- Uses global pkgs from flake (`useGlobalPkgs = true`)

## Modules

| Path | Purpose |
|------|---------|
| `home/core/identity.nix` | Username and home directory |
| `home/core/state-version.nix` | home.stateVersion |
| `home/core/home-manager.nix` | Enable Home Manager |
| `home/desktop/cursor.nix` | Pointer cursor theme |
| `home/programs/git.nix` | Git identity (user.name / user.email) |
| `home/programs/utilities.nix` | CLI utilities |
| `home/programs/google-chrome.nix` | Google Chrome |
| `home/programs/spotify.nix` | Spotify |
| `home/programs/discord.nix` | Discord |
| `home/programs/cursor.nix` | Cursor editor and CLI |
| `home/programs/claude-code.nix` | Claude Code (`pkgsUnstable.claude-code`) |

## Conventions

- Managed config files that may already exist on disk → `force = true`
- One program or one dconf domain per file
- Cinnamon settings are left to the DE GUI for now (no shared dconf modules yet)
