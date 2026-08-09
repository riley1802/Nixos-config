# Home Manager

- User: `rileyt`
- Entries:
  - Desktop (`nixos`): `home/nixos.nix` → `home/common.nix` + desktop-only modules
  - Legion (unused): `home.nix` → `home/common.nix` only
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
| `home/programs/gitnexus.nix` | GitNexus CLI + Cursor MCP + `serve` user service (**desktop only**) |

## Conventions

- Managed config files that may already exist on disk → `force = true`
- One program or one dconf domain per file
- Cinnamon settings are left to the DE GUI for now (no shared dconf modules yet)
- Desktop-only tools go in `home/nixos.nix` imports, not `home/common.nix`
