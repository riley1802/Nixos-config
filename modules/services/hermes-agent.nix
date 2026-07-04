{ inputs, lib, ... }:

{
  imports = [
    inputs.hermes-agent.nixosModules.default
  ];

  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;

    settings = {
      model = {
        provider = "llamacpp";
        default = "gemma-4-e4b-q8";
        base_url = "http://127.0.0.1:8080/v1";
      };
      terminal.backend = "local";
    };
  };

  users.users.rileyt.extraGroups = [ "hermes" ];

  systemd.services.hermes-agent = {
    after = [ "llama-cpp.service" ];
    requires = [ "llama-cpp.service" ];
  };
}
