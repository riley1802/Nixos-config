{ config, lib, ... }:

let
  tailnet = config.host.tailnetName;

  gpuTiles = lib.imap0
    (index: label: {
      "${label}" = {
        icon = if index == 0 then "mdi-expansion-card" else "mdi-expansion-card-variant";
        description = "GPU ${toString index} · util · VRAM · temp";
        widget = {
          type = "customapi";
          url = "http://127.0.0.1:8091/gpu/${toString index}";
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
    })
    config.host.gpus;
in
{
  services.homepage-dashboard = {
    enable = true;
    listenPort = 8083;
    openFirewall = false;
    # Accept Tailscale Serve / MagicDNS, plus local access on the bind port.
    allowedHosts = "${tailnet},localhost:8083,127.0.0.1:8083";

    settings = {
      title = "Homepage";
      theme = "dark";
      color = "slate";
      headerStyle = "boxedWidgets";
      fullWidth = true;
      statusStyle = "dot";
      useEqualHeights = true;
      target = "_blank";
      iconStyle = "theme";
      maxGroupColumns = 4;
      disableCollapse = true;

      layout = [
        {
          "System & Monitoring" = {
            style = "column";
            icon = "mdi-monitor-dashboard";
          };
        }
        {
          "Network & Infra" = {
            style = "column";
            icon = "mdi-lan";
          };
        }
        {
          "AI / Local" = {
            style = "column";
            icon = "mdi-robot-outline";
          };
        }
        {
          Productivity = {
            style = "column";
            icon = "mdi-briefcase-outline";
          };
        }
        {
          Developer = {
            icon = "mdi-code-braces";
          };
        }
        {
          Social = {
            icon = "mdi-account-group";
          };
        }
        {
          Entertainment = {
            icon = "mdi-play-circle-outline";
          };
        }
      ];
    };

    widgets = [
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
          provider = "duckduckgo";
          target = "_blank";
        };
      }
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
        openmeteo = {
          label = "Chicago";
          latitude = 41.8781;
          longitude = -87.6298;
          timezone = "America/Chicago";
          units = "imperial";
          cache = 5;
        };
      }
    ];

    services = [
      {
        "System & Monitoring" =
          [
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
              Network = {
                icon = "mdi-swap-vertical-bold";
                description = "Ethernet · live throughput";
                widget = {
                  type = "customapi";
                  url = "http://127.0.0.1:8091/network";
                  refreshInterval = 5000;
                  mappings = [
                    {
                      field = "rx_mbps";
                      label = "Down";
                      format = "float";
                      suffix = " Mbps";
                    }
                    {
                      field = "tx_mbps";
                      label = "Up";
                      format = "float";
                      suffix = " Mbps";
                    }
                  ];
                };
              };
            }
          ]
          ++ gpuTiles
          ++ [
            {
              "Uptime Kuma" = {
                icon = "uptime-kuma.png";
                href = "http://127.0.0.1:3001";
                description = "Status dashboard";
                siteMonitor = "http://127.0.0.1:3001";
              };
            }
          ];
      }
      {
        "Network & Infra" = [
          {
            Tailscale = {
              icon = "si-tailscale";
              href = "https://login.tailscale.com/admin/machines";
              description = "Tailnet admin";
            };
          }
          {
            Portainer = {
              icon = "portainer.png";
              href = "https://${tailnet}:9443";
              description = "Container management";
              siteMonitor = "https://127.0.0.1:9443";
            };
          }
          {
            ntfy = {
              icon = "ntfy.png";
              href = "http://${tailnet}:8090";
              description = "Push notifications";
              siteMonitor = "http://127.0.0.1:8090";
            };
          }
        ];
      }
      {
        "AI / Local" = [
          {
            "llama.cpp dual" = {
              icon = "si-ollama";
              href = "https://${tailnet}:8084";
              description = "Nemotron :8084 + Qwen :8085 (default)";
              siteMonitor = "http://127.0.0.1:8084/v1/models";
            };
          }
          {
            "llama.cpp Phi" = {
              icon = "si-ollama";
              href = "https://${tailnet}:8080";
              description = "Phi-4 exclusive (llama-cpp-mode phi)";
              siteMonitor = "http://127.0.0.1:8080/v1/models";
            };
          }
          {
            "whisper.cpp" = {
              icon = "mdi-microphone";
              href = "https://${tailnet}:8081";
              description = "Speech-to-text";
              siteMonitor = "http://127.0.0.1:8081";
            };
          }
          {
            Piper = {
              icon = "mdi-volume-high";
              href = "https://${tailnet}:8082/health";
              description = "Text-to-speech";
              siteMonitor = "http://127.0.0.1:8082/health";
            };
          }
          {
            "Unsloth Studio" = {
              icon = "mdi-school";
              href = "https://${tailnet}:8000";
              description = "Fine-tune & chat (Docker + CUDA)";
              siteMonitor = "http://127.0.0.1:8000";
            };
          }
        ];
      }
      {
        Productivity = [
          {
            n8n = {
              icon = "n8n.png";
              href = "https://${tailnet}:5678";
              description = "Workflow automation";
              siteMonitor = "http://127.0.0.1:5678/healthz";
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
    ];

    bookmarks = [
      {
        Developer = [
          {
            GitHub = [
              {
                icon = "si-github";
                href = "https://github.com";
              }
            ];
          }
          {
            "NixOS Options" = [
              {
                icon = "si-nixos";
                href = "https://search.nixos.org/options";
              }
            ];
          }
          {
            "Home Manager Options" = [
              {
                icon = "mdi-home-account";
                href = "https://home-manager-options.extranix.com";
              }
            ];
          }
        ];
      }
      {
        Social = [
          {
            Reddit = [
              {
                icon = "si-reddit";
                href = "https://www.reddit.com";
              }
            ];
          }
          {
            LinkedIn = [
              {
                icon = "si-linkedin";
                href = "https://www.linkedin.com";
              }
            ];
          }
        ];
      }
      {
        Entertainment = [
          {
            YouTube = [
              {
                icon = "si-youtube";
                href = "https://youtube.com";
              }
            ];
          }
          {
            "Homepage Docs" = [
              {
                icon = "mdi-book-open-page-variant";
                href = "https://gethomepage.dev";
              }
            ];
          }
        ];
      }
    ];
  };

  # Homepage has no bind-address option and listens on all interfaces, unlike the localhost-only
  # AI services. Port 8083 stays closed; Tailscale clients reach it via Serve on :443.
}
