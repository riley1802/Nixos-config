# Imports every .nix file under modules/. A new module is just a new file.
{ lib, ... }:
{
  imports = builtins.filter (f: lib.hasSuffix ".nix" (toString f) && baseNameOf f != "default.nix") (
    lib.filesystem.listFilesRecursive ./.
  );
}
