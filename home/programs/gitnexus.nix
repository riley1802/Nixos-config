{ config, lib, pkgs, inputs, ... }:

let
  gitnexus = inputs.llm-agents.packages.${pkgs.system}.gitnexus;

  mcpJsonFile = pkgs.writeText "gitnexus-mcp.json" (builtins.toJSON {
    mcpServers = {
      gitnexus = {
        command = "${gitnexus}/bin/gitnexus";
        args = [ "mcp" ];
      };
    };
  });
in
{
  home.packages = [ gitnexus ];

  # Cursor cannot follow HM symlinks for MCP config — copy a real file and
  # merge the gitnexus server entry if other servers already exist.
  home.activation.gitnexusCursorMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mcp_path="${config.home.homeDirectory}/.cursor/mcp.json"
    $DRY_RUN_CMD mkdir -p "${config.home.homeDirectory}/.cursor"
    if [ -f "$mcp_path" ]; then
      $DRY_RUN_CMD ${pkgs.jq}/bin/jq \
        --slurpfile gn ${mcpJsonFile} \
        '.mcpServers = (.mcpServers // {}) | .mcpServers.gitnexus = $gn[0].mcpServers.gitnexus' \
        "$mcp_path" > "$mcp_path.tmp"
      $DRY_RUN_CMD mv "$mcp_path.tmp" "$mcp_path"
    else
      $DRY_RUN_CMD cp -f ${mcpJsonFile} "$mcp_path"
    fi
  '';

  # Local HTTP backend for https://gitnexus.vercel.app (localhost:4747).
  systemd.user.services.gitnexus-serve = {
    Unit = {
      Description = "GitNexus local web UI backend";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${gitnexus}/bin/gitnexus serve --host localhost --port 4747";
      Restart = "on-failure";
      RestartSec = "5";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
