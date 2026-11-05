# Packages that replace the nixos-26.05 versions.
{ inputs, lib, ... }:
let
  unstable = import inputs.nixpkgs-unstable {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
{
  # Cursor, Radarr, and Sonarr come from unstable. nixos-26.05 Sonarr is
  # 4.0.19.2979, and the app was warning that 4.0.20.3014 was out. That
  # version is the sonarr package on this unstable pin. Lidarr's current
  # release is not packaged yet, so use the official build in
  # packages/lidarr.nix.
  # Uptime Kuma 2.5.8 is newer than both nixpkgs pins.
  # Immich comes from unstable because nixos-26.05 has 2.7.5, which
  # is marked insecure, and phone apps need 3.x. The unstable pin's
  # package is 3.3.5. machine-learning is passthru on that package,
  # and both derivations set mainProgram, so the 26.05 module's
  # lib.getExe calls keep server and ML on the same release.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/pkgs/by-name/im/immich/package.nix
  # https://github.com/NixOS/nixpkgs/blob/31ecbaca1bdefa45dffc409f0250bd8039ea0010/pkgs/by-name/im/immich/package.nix
  nixpkgs.overlays = [
    (final: prev:
      lib.packagesFromDirectoryRecursive
        {
          inherit (prev) callPackage;
          directory = ../../packages;
        }
      // {
        inherit (unstable) radarr sonarr immich;
        # n8n 2.34.6 ships generated runtime schemas, but its MCP resolver
        # looks for matching .ts filenames. Keep the package version and
        # expose compatibility links so workflow node types can be queried.
        n8n = prev.callPackage ../../packages/n8n-mcp.nix { n8n = prev.n8n; };
        code-cursor = unstable.code-cursor.overrideAttrs (
          old:
          let
            version = "3.27.22";
          in
          {
            inherit version;
            src = unstable.appimageTools.extract {
              pname = "cursor";
              inherit version;
              src = unstable.fetchurl {
                url = "https://downloads.cursor.com/production/b1aa50cb6db84fd3e8c808259cb172ea73425c1f/linux/x64/Cursor-3.27.22-x86_64.AppImage";
                hash = "sha256-TbL+Na4ZIwHdWzQjedCgQavb3W2QKe/ggwCM/aoC+A4=";
              };
            };
            sourceRoot = "cursor-${version}-extracted/usr/share/cursor";
          }
        );
      })
  ];
}
