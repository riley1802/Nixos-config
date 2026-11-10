# n8n workflow editor. Web page on port 5678.
{ config, lib, pkgs, ... }:
let
  cfg = config.my.services.n8n;
  # n8n 2.34.6 generates Zod schemas as *.schema.js, then the Nix package
  # deletes every *.ts file. The MCP resolver only opens *.ts, so node
  # definitions such as Postgres disappear. This copy keeps the same build
  # and adds a hard link for each schema. It does not rebuild n8n.
  mcpNodeTypes = pkgs.runCommand "${pkgs.n8n.name}-mcp-node-types"
    {
      nativeBuildInputs = [
        pkgs.coreutils
        pkgs.findutils
      ];
      meta = pkgs.n8n.meta;
      passthru = pkgs.n8n.passthru or { };
    }
    ''
      cp -a --reflink=auto ${pkgs.n8n}/. "$out/"

      # The installed launcher contains the original output path. Point it at
      # this copy so Node resolves packages containing the compatibility links.
      chmod u+w "$out/bin/n8n"
      substituteInPlace "$out/bin/n8n" \
        --replace-fail '${pkgs.n8n}' "$out"

      while IFS= read -r -d "" source; do
        # Copied store directories are mode 555. The builder is not root, so
        # the directory must be writable before the link can be created.
        chmod u+w "$(dirname "$source")"
        target="''${source%.schema.js}.ts"
        # A hard link is a regular file. The MCP resolver ignores symlinks
        # when it lists version and mode files.
        ln "$source" "$target"
      done < <(
        find "$out/lib/n8n" \
          -type f \
          -path "*/dist/node-definitions/*" \
          -name "*.schema.js" \
          -print0
      )
    '';
in
{
  options.my.services.n8n.enable = lib.mkEnableOption "n8n";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.my.network.tailscale.enable;
        message = "services/n8n needs network/tailscale (nixctl enable network/tailscale)";
      }
    ];

    # n8n 2.34.6 from the nixos-26.05 module. The editor listens on loopback.
    # Chrome's HSTS list upgrades http://*.ts.net to HTTPS on the same port,
    # so Tailscale Serve terminates TLS on 5678 and proxies here.
    # modules/network/tailscale.nix installs that route. openFirewall stays
    # false so 5678 is not opened on every interface.
    # https://github.com/NixOS/nixpkgs/blob/nixos-26.05/nixos/modules/services/misc/n8n.nix
    # https://docs.n8n.io/hosting/configuration/environment-variables/
    services.n8n = {
      enable = true;
      package = mcpNodeTypes;
      openFirewall = false;
      environment = {
        N8N_LISTEN_ADDRESS = "127.0.0.1";
        N8N_PORT = 5678;
        N8N_PROTOCOL = "https";
        N8N_HOST = config.my.tailnetHost;
        # 2.34.6 still accepts WEBHOOK_URL and warns to use this name instead.
        N8N_WEBHOOK_URL = "https://${config.my.tailnetHost}:5678/";
        # OAuth redirect origin. n8n builds
        # /rest/oauth2-credential/callback from this URL. Spotify allows
        # plain HTTP only for 127.0.0.1 and rejects the tailnet host and
        # the name localhost. Connect from a browser on this PC.
        # https://developer.spotify.com/documentation/web-api/concepts/redirect_uri
        N8N_EDITOR_BASE_URL = "http://127.0.0.1:5678/";
        # Tailscale Serve sets X-Forwarded-Proto. One hop is that proxy.
        N8N_PROXY_HOPS = 1;
        # Stays false so a login at http://127.0.0.1:5678 still works. The
        # Secure flag would drop that cookie because loopback is HTTP.
        N8N_SECURE_COOKIE = false;
      };
    };

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      5678 # n8n
    ];
  };
}
