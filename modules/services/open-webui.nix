{ pkgs, ... }:

{
  services.open-webui = {
    enable = true;
    package = pkgs.open-webui;

    stateDir = "/var/lib/open-webui";

    host = "127.0.0.1";
    port = 3000;
    openFirewall = false;

    environment = {
      SCARF_NO_ANALYTICS = "True";
      DO_NOT_TRACK = "True";
      ANONYMIZED_TELEMETRY = "False";
      ENABLE_PERSISTENT_CONFIG = "False";

      ENABLE_OLLAMA_API = "False";
      ENABLE_OPENAI_API = "True";
      OPENAI_API_BASE_URL = "http://127.0.0.1:8080/v1";
      OPENAI_API_KEY = "none";
      ENABLE_WEB_SEARCH = "True";
      WEB_SEARCH_ENGINE = "searxng";
      WEB_SEARCH_RESULT_COUNT = "3";
      WEB_SEARCH_CONCURRENT_REQUESTS = "2";
      WEB_LOADER_CONCURRENT_REQUESTS = "5";
      BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL = "False";
      BYPASS_WEB_SEARCH_WEB_LOADER = "True";
      SEARXNG_QUERY_URL = "http://127.0.0.1:8888/search?q=<query>";
      SEARXNG_LANGUAGE = "all";
      WEBUI_AUTH = "True";
      WEBUI_NAME = "Local llama.cpp";
    };

    environmentFile = null;
  };
}
