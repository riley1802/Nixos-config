# Module Patterns

## Service module

```nix
{ pkgs, pkgsUnstable, lib, ... }:

{
  services.example.enable = true;
}
```

Import one line in `configuration.nix`.

## Home program module

```nix
{ pkgs, ... }:

{
  home.packages = [ pkgs.some-package ];
}
```

Import one line in `home.nix`.

## README sync

When config changes, also update repo `README.md`:

- Layout table (new top-level dirs)
- Local AI Stack table + service subsections
- Usage / status commands
