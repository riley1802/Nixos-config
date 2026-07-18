{ config, ... }:
{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8083;
    openFirewall = false;
    # Accept Tailscale Serve / MagicDNS, plus local access on the bind port.
    allowedHosts = "nixos.taile9f484.ts.net,localhost:8083,127.0.0.1:8083";

    # theme left unlocked so the built-in dark/light switcher stays available.
    # Dark is forced as the first-visit default via customJS; light is cooled in customCSS.
    settings = {
      title = "Homeport";
      description = "Local launchpad — services, weather, and live latency";
      color = "slate"; # cool geometric slate — not warm/amber night-light
      headerStyle = "boxedWidgets";
      hideVersion = true;
      disableCollapse = true;
      useEqualHeights = true;
      fullWidth = true;
      language = "en";
      target = "_blank";
      iconStyle = "theme";

      # List form preserves visual order (attrsets can get reordered when serialized).
      layout = [
        {
          System = {
            style = "row";
            columns = 3;
          };
        }
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
            columns = 3;
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
        System = [
          {
            Host = {
              icon = "mdi-server";
              description = "Load · RAM · uptime";
              widget = {
                type = "customapi";
                url = "http://127.0.0.1:8091/host";
                refreshInterval = 5000;
                mappings = [
                  {
                    field = "load1";
                    label = "Load";
                    format = "float";
                  }
                  {
                    field = "mem_used_pct";
                    label = "RAM";
                    format = "percent";
                  }
                  {
                    field = "mem_available_mib";
                    label = "Free";
                    format = "float";
                    suffix = " MiB";
                  }
                  {
                    field = "uptime_seconds";
                    label = "Up";
                    format = "duration";
                  }
                ];
              };
            };
          }
          {
            "RTX 3050" = {
              icon = "mdi-expansion-card";
              description = "GPU 0 · util · VRAM · temp";
              widget = {
                type = "customapi";
                url = "http://127.0.0.1:8091/gpu/0";
                refreshInterval = 5000;
                mappings = [
                  {
                    field = "util";
                    label = "GPU";
                    format = "percent";
                  }
                  {
                    field = "mem_pct";
                    label = "VRAM";
                    format = "percent";
                  }
                  {
                    field = "mem_used_mib";
                    label = "Used";
                    format = "float";
                    suffix = " MiB";
                  }
                  {
                    field = "temp_c";
                    label = "Temp";
                    format = "float";
                    suffix = "°C";
                  }
                ];
              };
            };
          }
          {
            "GTX 1660 Super" = {
              icon = "mdi-expansion-card-variant";
              description = "GPU 1 · util · VRAM · temp";
              widget = {
                type = "customapi";
                url = "http://127.0.0.1:8091/gpu/1";
                refreshInterval = 5000;
                mappings = [
                  {
                    field = "util";
                    label = "GPU";
                    format = "percent";
                  }
                  {
                    field = "mem_pct";
                    label = "VRAM";
                    format = "percent";
                  }
                  {
                    field = "mem_used_mib";
                    label = "Used";
                    format = "float";
                    suffix = " MiB";
                  }
                  {
                    field = "temp_c";
                    label = "Temp";
                    format = "float";
                    suffix = "°C";
                  }
                ];
              };
            };
          }
        ];
      }
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
              href = "https://nixos.taile9f484.ts.net:5678";
              description = "Workflow automation";
              siteMonitor = "http://127.0.0.1:5678/healthz";
            };
          }
          {
            Portainer = {
              icon = "portainer.png";
              href = "https://nixos.taile9f484.ts.net:9443";
              description = "Container management";
              siteMonitor = "https://127.0.0.1:9443";
            };
          }
        ];
      }
      {
        Monitoring = [
          {
            "World Monitor" = {
              icon = "mdi-earth";
              href = "https://nixos.taile9f484.ts.net:3000";
              description = "Global intelligence dashboard";
              siteMonitor = "http://127.0.0.1:3000";
            };
          }
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

    # Cool geometric chrome: slate grid, sharp cards, cool soft light (no warm cast).
    customCSS = ''
      html.dark body {
        background-color: #0b1220 !important;
        background-image:
          linear-gradient(rgba(148, 163, 184, 0.07) 1px, transparent 1px),
          linear-gradient(90deg, rgba(148, 163, 184, 0.07) 1px, transparent 1px);
        background-size: 40px 40px;
      }

      html.dark .service,
      html.dark .bookmark {
        border-radius: 2px !important;
        box-shadow: inset 0 0 0 1px rgba(148, 163, 184, 0.18);
        backdrop-filter: none;
      }

      html.dark .service-group,
      html.dark .bookmark-group {
        border-radius: 2px;
      }

      /* Soft light — cool gray paper, never warm/orange, never pure white */
      html.light body {
        background-color: #d7dce5 !important;
        background-image:
          linear-gradient(rgba(71, 85, 105, 0.08) 1px, transparent 1px),
          linear-gradient(90deg, rgba(71, 85, 105, 0.08) 1px, transparent 1px);
        background-size: 40px 40px;
      }

      html.light {
        filter: brightness(0.95) contrast(0.98) saturate(0.92);
      }

      html.light .service,
      html.light .bookmark {
        border-radius: 2px !important;
        box-shadow: inset 0 0 0 1px rgba(71, 85, 105, 0.2);
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
  # AI services. Port 8083 stays closed; Tailscale clients reach it via Serve on :443.
}
