{ pkgs, lib, ... }:

let
  llamaCppProvider = {
    name = "llama_cpp";
    engine = "openai";
    display_name = "Local llama.cpp";
    description = "llama.cpp server on this machine";
    base_url = "http://127.0.0.1:8080/v1";
    models = [
      {
        name = "gemma-4-e4b-q8";
        context_limit = 4096;
      }
      {
        name = "nemotron-nano-12b-v2-q4";
        context_limit = 4096;
      }
      {
        name = "gemma-4-12b-q4-mtp";
        context_limit = 4096;
      }
    ];
    supports_streaming = true;
    requires_auth = false;
  };

  gooseConfig = {
    GOOSE_PROVIDER = "llama_cpp";
    GOOSE_MODEL = "gemma-4-e4b-q8";
    GOOSE_MODE = "smart_approve";
    GOOSE_TELEMETRY_ENABLED = false;
    GOOSE_MAX_TURNS = 50;

    extensions = {
      analyze = {
        enabled = true;
        type = "platform";
        name = "analyze";
        description = "Analyze code structure with tree-sitter: directory overviews, file details, symbol call graphs";
        display_name = "Analyze";
        bundled = true;
        available_tools = [ ];
      };
      extensionmanager = {
        enabled = true;
        type = "platform";
        name = "Extension Manager";
        description = "Enable extension management tools for discovering, enabling, and disabling extensions";
        display_name = "Extension Manager";
        bundled = true;
        available_tools = [ ];
      };
      summon = {
        enabled = true;
        type = "platform";
        name = "summon";
        description = "Load knowledge and delegate tasks to subagents";
        display_name = "Summon";
        bundled = true;
        available_tools = [ ];
      };
      todo = {
        enabled = true;
        type = "platform";
        name = "todo";
        description = "Enable a todo list for goose so it can keep track of what it is doing";
        display_name = "Todo";
        bundled = true;
        available_tools = [ ];
      };
      developer = {
        enabled = true;
        type = "platform";
        name = "developer";
        description = "Write and edit files, and execute shell commands";
        display_name = "Developer";
        bundled = true;
        available_tools = [ ];
      };
    };
  };
in
{
  home.packages = [
    pkgs.goose-cli
    pkgs.goose-desktop
    (pkgs.writeShellScriptBin "goose-launch" ''
      #!${pkgs.bash}/bin/bash
      exec ${lib.getExe pkgs.gnome-console} -T Goose -e -- ${lib.getExe pkgs.goose-cli} session
    '')
  ];

  xdg.configFile."goose/config.yaml" = {
    source = (pkgs.formats.yaml { }).generate "goose-config.yaml" gooseConfig;
    force = true;
  };

  xdg.configFile."goose/custom_providers/llama-cpp.json" = {
    source = pkgs.writeText "llama-cpp-provider.json" (builtins.toJSON llamaCppProvider);
    force = true;
  };

  xdg.dataFile."applications/goose-cli.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=Goose CLI
    Comment=Goose terminal session powered by llama.cpp
    Exec=goose-launch
    Icon=utilities-terminal
    Terminal=false
    Categories=Development;Utility;
    StartupNotify=true
  '';
}
