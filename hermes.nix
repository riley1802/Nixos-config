{ ... }:

{
  services.hermes-agent = {
    enable = true;
    addToSystemPackages = true;
    user = "rileyt";
    group = "users";
    createUser = false;

    settings.model = {
      provider = "custom";
      default = "gemma-4-12b-it-qat";
      base_url = "http://127.0.0.1:8080/v1";
      api_key = "";
      api_mode = "chat_completions";
      context_length = 65536;
    };
  };

  systemd.services.hermes-agent = {
    requires = [ "llama-cpp-gemma4.service" ];
    after = [ "llama-cpp-gemma4.service" ];
  };
}
