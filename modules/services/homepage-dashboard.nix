{ config, ... }:
{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8083;
    openFirewall = false;
    # Accept Tailscale MagicDNS via nginx, plus local access on the bind port.
    allowedHosts = "nixos.taile9f484.ts.net,localhost:8083,127.0.0.1:8083";

    # theme left unlocked so the built-in dark/light switcher stays available.
    # Dark is forced as the first-visit default via customJS; light is softened in customCSS.
    settings = {
      title = "Homeport";
      description = "Local launchpad — services, weather, and live latency";
      color = "amber"; # warm copper/saffron — uncommon vs blue/teal/purple defaults
      headerStyle = "boxedWidgets";
      hideVersion = true;
      disableCollapse = true;
      useEqualHeights = true;
      fullWidth = true;
      language = "en";
      target = "_blank";
      iconStyle = "theme";

      # Soft dusk atmosphere via remote image + heavy filters (tasteful, not busy).
      background = {
        image = "https://images.unsplash.com/photo-1419242902214-272b3f66ee7a?auto=format&fit=crop&w=2560&q=80";
        blur = "md";
        saturate = 50;
        brightness = 40;
        opacity = 30;
      };

      # List form preserves visual order (attrsets can get reordered when serialized).
      layout = [
        {
          "AI / Local Models" = {
            style = "row";
            columns = 4;
          };
        }
        {
          "Automation & Infra" = {
            style = "row";
            columns = 2;
          };
        }
        {
          Monitoring = {
            style = "row";
            columns = 2;
          };
        }
        {
          External = {
            style = "row";
            columns = 4;
          };
        }
      ];
    };

    services = [
      {
        "AI / Local Models" = [
          {
            "llama.cpp" = {
              icon = "si-ollama";
              href = "http://127.0.0.1:8080";
              description = "Local LLM inference";
              siteMonitor = "http://127.0.0.1:8080/v1/models";
            };
          }
          {
            "whisper.cpp" = {
              icon = "mdi-microphone";
              href = "http://127.0.0.1:8081/v1/audio/transcriptions";
              description = "Speech-to-text";
              siteMonitor = "http://127.0.0.1:8081";
            };
          }
          {
            "Piper TTS" = {
              icon = "mdi-volume-high";
              href = "http://127.0.0.1:8082";
              description = "Text-to-speech";
              siteMonitor = "http://127.0.0.1:8082/health";
            };
          }
          {
            SearXNG = {
              icon = "si-searxng";
              href = "http://127.0.0.1:8888";
              description = "Metasearch";
              siteMonitor = "http://127.0.0.1:8888";
            };
          }
        ];
      }
      {
        "Automation & Infra" = [
          {
            n8n = {
              icon = "n8n.png";
              href = "/n8n/";
              description = "Workflow automation";
              siteMonitor = "http://127.0.0.1:5678/healthz";
            };
          }
          {
            Portainer = {
              icon = "portainer.png";
              href = "/portainer/";
              description = "Container management";
              siteMonitor = "https://127.0.0.1:9443";
            };
          }
        ];
      }
      {
        Monitoring = [
          {
            "Uptime Kuma" = {
              icon = "uptime-kuma.png";
              href = "http://127.0.0.1:3001";
              description = "Status dashboard";
              siteMonitor = "http://127.0.0.1:3001";
            };
          }
          {
            ntfy = {
              icon = "ntfy.png";
              href = "http://nixos.taile9f484.ts.net:8090";
              description = "Push notifications";
              siteMonitor = "http://127.0.0.1:8090";
            };
          }
        ];
      }
    ];

    bookmarks = [
      {
        External = [
          {
            GitHub = [
              {
                abbr = "GH";
                href = "https://github.com";
              }
            ];
          }
          {
            "NixOS Options Search" = [
              {
                abbr = "NO";
                href = "https://search.nixos.org/options";
              }
            ];
          }
          {
            "Home Manager Options" = [
              {
                abbr = "HM";
                href = "https://home-manager-options.extranix.com";
              }
            ];
          }
          {
            "Homepage Docs" = [
              {
                abbr = "HD";
                href = "https://gethomepage.dev";
              }
            ];
          }
        ];
      }
    ];

    widgets = [
      {
        datetime = {
          text_size = "xl";
          locale = "en-US";
          format = {
            timeStyle = "short";
            dateStyle = "medium";
            hour12 = true;
          };
        };
      }
      {
        # Coords follow system timezone America/Chicago — adjust if you're elsewhere.
        openmeteo = {
          label = "Outside";
          latitude = 41.8781;
          longitude = -87.6298;
          timezone = "America/Chicago";
          units = "imperial";
          cache = 5;
          format = {
            maximumFractionDigits = 0;
          };
        };
      }
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
          uptime = true;
        };
      }
      {
        search = {
          provider = "custom";
          url = "http://127.0.0.1:8888/search?q=";
          target = "_blank";
          focus = false;
        };
      }
    ];

    # Soft light mode: warm parchment + slight dim so night flips don't blind.
    # Dark mode: subtle amber edge glow on cards for density without clutter.
    customCSS = ''
      /* Soft light — warm paper, never pure white */
      html.light body {
        background-color: #e4ddd0 !important;
      }

      html.light {
        filter: brightness(0.93) contrast(0.97);
      }

      html.light .service-group,
      html.light .bookmark-group {
        backdrop-filter: blur(6px);
      }

      /* Dark — quiet amber rim so dense tiles stay readable */
      html.dark .service {
        box-shadow: inset 0 0 0 1px rgba(251, 191, 36, 0.08);
      }

      html.dark body {
        background-color: #0c0a09;
      }
    '';

    # First visit defaults to dark; afterwards the theme switcher / localStorage wins.
    customJS = ''
      (() => {
        try {
          if (localStorage.getItem("theme") == null) {
            localStorage.setItem("theme", "dark");
            document.documentElement.classList.add("dark");
            document.documentElement.classList.remove("light");
            document.documentElement.style.colorScheme = "dark";
          }
        } catch (_) {}
      })();
    '';
  };

  # Homepage has no bind-address option and listens on all interfaces, unlike the localhost-only
  # AI services. Port 8083 stays closed; Tailscale clients reach it through nginx on port 80.
}
