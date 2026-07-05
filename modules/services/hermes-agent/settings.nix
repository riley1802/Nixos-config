# Declarative Hermes config (merged into /var/lib/hermes/.hermes/config.yaml on rebuild).
{ hasHermesEnv, lib, ... }:
{
  model = {
    provider = "llamacpp";
    default = "gemma-4-e4b-q8";
    base_url = "http://127.0.0.1:8080/v1";
  };

  terminal = {
    backend = "local";
    cwd = "/var/lib/hermes/workspace";
    timeout = 180;
    home_mode = "auto";
  };

  platform_toolsets = {
    cli = [
      "hermes-cli"
      "spotify"
    ];
  }
  // lib.optionalAttrs hasHermesEnv {
    discord = [
      "hermes-discord"
      "spotify"
    ];
  };

  web = {
    search_backend = "searxng";
  };

  compression = {
    enabled = true;
    threshold = 0.50;
    target_ratio = 0.20;
    protect_last_n = 20;
    protect_first_n = 3;
  };

  memory = {
    memory_enabled = true;
    user_profile_enabled = true;
    memory_char_limit = 2200;
    user_char_limit = 1375;
    nudge_interval = 10;
    flush_min_turns = 6;
  };

  stt = {
    enabled = true;
    local = {
      model = "base";
    };
  };

  auxiliary = {
    vision = {
      provider = "main";
    };
    web_extract = {
      provider = "main";
    };
    session_search = {
      provider = "main";
    };
  };

  display = {
    tool_progress = "all";
    interim_assistant_messages = true;
    long_running_notifications = true;
    busy_input_mode = "interrupt";
    streaming = true;
  };

  gateway = {
    unauthorized_dm_behavior = "pair";
  };
}
  // lib.optionalAttrs hasHermesEnv {
  discord = {
    require_mention = false;
    auto_thread = false;
    reactions = true;
    allowed_channels = [
      "1523125568856653874"
    ];
    channel_prompts = {
      "1523125568856653874" = ''
        Spotify is connected. For play/pause/queue requests: use spotify_devices then spotify_playback — do not refuse or offer manual URIs. Liked songs: spotify_library (kind=tracks) then spotify_playback play with uris + shuffle.
      '';
    };
  };
}
