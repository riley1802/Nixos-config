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

      # Whiteboard grid (list form preserves visual order):
      #   1 System (full width)
      #   2 header widgets = at-a-glance (time, weather, resources, search)
      #   3 Apps + Bookmarks (separate) | 4 Automation | 5 Monitoring
      #   6 AI / Local | 7 Containers
      # Bookmarks are service tiles (not bookmarks.yaml) so they can nest in the
      # Workspace row beside Apps — Homepage cannot nest bookmark groups.
      layout = [
        {
          System = {
            style = "row";
            columns = 3;
          };
        }
        {
          Workspace = {
            header = false;
            style = "row";
            columns = 4;
            Apps = {
              style = "row";
              columns = 2;
            };
            Bookmarks = {
              style = "row";
              columns = 2;
            };
            Automation = {
              style = "column";
              columns = 1;
            };
            Monitoring = {
              style = "column";
              columns = 1;
            };
          };
        }
        {
          Bottom = {
            header = false;
            style = "row";
            columns = 2;
            "AI / Local" = {
              style = "row";
              columns = 3;
            };
            Containers = {
              style = "row";
              columns = 1;
            };
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
        # Middle row: Apps | Bookmarks | Automation | Monitoring
        Workspace = [
          {
            Apps = [
              {
                SearXNG = {
                  icon = "si-searxng";
                  href = "http://127.0.0.1:8888";
                  description = "Metasearch";
                  siteMonitor = "http://127.0.0.1:8888";
                };
              }
              {
                "Metrics API" = {
                  icon = "mdi-chart-line";
                  href = "http://127.0.0.1:8091";
                  description = "Host · GPU JSON";
                  siteMonitor = "http://127.0.0.1:8091";
                };
              }
              {
                Tailscale = {
                  icon = "si-tailscale";
                  href = "https://login.tailscale.com/admin/machines";
                  description = "Tailnet admin";
                };
              }
            ];
          }
          {
            Bookmarks = [
              {
                GitHub = {
                  icon = "si-github";
                  href = "https://github.com";
                  description = "github.com";
                };
              }
              {
                "NixOS Options" = {
                  icon = "si-nixos";
                  href = "https://search.nixos.org/options";
                  description = "search.nixos.org";
                };
              }
              {
                "Home Manager Options" = {
                  icon = "mdi-home-account";
                  href = "https://home-manager-options.extranix.com";
                  description = "HM option search";
                };
              }
              {
                "Homepage Docs" = {
                  icon = "mdi-book-open-page-variant";
                  href = "https://gethomepage.dev";
                  description = "gethomepage.dev";
                };
              }
            ];
          }
          {
            Automation = [
              {
                n8n = {
                  icon = "n8n.png";
                  href = "https://nixos.taile9f484.ts.net:5678";
                  description = "Workflow automation";
                  siteMonitor = "http://127.0.0.1:5678/healthz";
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
      }
      {
        # Bottom row: AI / Local | Containers
        Bottom = [
          {
            "AI / Local" = [
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
            ];
          }
          {
            Containers = [
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
        ];
      }
    ];

    # External links live under Workspace → Bookmarks (services) so the middle
    # row can keep Apps and Bookmarks as separate cells. bookmarks.yaml unused.
    bookmarks = [ ];

    # At-a-glance bar (section 2): time, weather, host resources. The System
    # services group (Host + network + both GPU tiles) is relocated here at runtime by
    # customJS, into the slot the search widget used to occupy.
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
        # expanded=true renders the extra detail row (load avg / mem used-total /
        # disk free) into the DOM so customCSS/customJS below can toggle it on click.
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
          uptime = true;
          expanded = true;
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

      /* Service tiles: flat fills, no per-card outline — section border is the frame. */
      html.dark .service,
      html.dark .bookmark,
      html.dark .service-card {
        border-radius: 2px !important;
        border: none !important;
        box-shadow: none !important;
        backdrop-filter: none;
      }

      html.dark .service-card {
        background-color: rgba(51, 65, 85, 0.45) !important;
        margin-bottom: 0 !important;
        height: auto !important;
        min-height: 3.25rem;
      }

      /* More space between clickable service tiles. */
      .services-list {
        gap: 1.25rem !important;
        row-gap: 1.25rem !important;
        column-gap: 1.25rem !important;
        margin-top: 0.85rem !important;
      }

      /* Bounding box around the whole section (title + tiles), not each tile. */
      .services-group.subgroup,
      #layout-groups > .services-group.p-1,
      #information-widgets {
        border-radius: 3px;
        border: 1px solid rgba(148, 163, 184, 0.75) !important;
        padding: 0.85rem 1rem 1.1rem !important;
        margin: 0.55rem !important;
        box-sizing: border-box;
        background-color: rgba(2, 6, 23, 0.55);
      }

      html.dark .services-group.subgroup,
      html.dark #layout-groups > .services-group.p-1,
      html.dark #information-widgets {
        border-color: rgba(148, 163, 184, 0.75) !important;
        background-color: rgba(2, 6, 23, 0.55);
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
      html.light .bookmark,
      html.light .service-card {
        border-radius: 2px !important;
        border: none !important;
        box-shadow: none !important;
      }

      html.light .service-card {
        background-color: rgba(255, 255, 255, 0.65) !important;
        margin-bottom: 0 !important;
      }

      html.light .services-group.subgroup,
      html.light #layout-groups > .services-group.p-1,
      html.light #information-widgets {
        border: 1px solid rgba(71, 85, 105, 0.5) !important;
        background-color: rgba(255, 255, 255, 0.4);
      }

      /* Click-to-expand resources box (CPU/RAM/disk/uptime): the detail row
         (load avg, mem used/total, disk free) is hidden until toggled by customJS. */
      .widget-container:has(.information-widget-resource) {
        cursor: pointer;
      }

      .information-widget-resource .expanded > div:nth-child(2) {
        display: none;
      }

      .widget-container.resources-expanded .information-widget-resource .expanded > div:nth-child(2) {
        display: flex;
      }

      /* System group relocated into the info-widgets row (where "search" used to
         sit): remove section chrome so its cards align with the native widgets. */
      #information-widgets-right .services-group {
        width: auto;
        margin: 0 !important;
        padding: 0 !important;
      }

      #information-widgets-right .services-group > button {
        display: none;
      }

      #information-widgets-right .services-group .services-list {
        display: flex !important;
        flex-direction: row;
        gap: 0.5rem !important;
        margin-top: 0 !important;
      }

      /* Fullscreen 1440p target: one compact, balanced row. Fixed widths keep
         native widgets readable; the four System cards evenly share the rest. */
      @media (min-width: 1600px) {
        #widgets-wrap {
          display: grid !important;
          grid-template-columns: 520px minmax(0, 1fr) !important;
          gap: 16px !important;
          align-items: stretch !important;
        }

        #widgets-wrap > .widget-container {
          width: auto !important;
          min-width: 0 !important;
          height: 100% !important;
          margin: 0 !important;
          flex: none !important;
        }

        #information-widgets-right {
          display: grid !important;
          grid-template-columns: 240px 210px minmax(0, 1fr) !important;
          gap: 12px !important;
          align-items: stretch !important;
          min-width: 0 !important;
          height: 100% !important;
          margin: 0 !important;
          flex: none !important;
        }

        #information-widgets-right > .widget-container {
          width: auto !important;
          min-width: 0 !important;
          height: 100% !important;
          margin: 0 !important;
          flex: none !important;
        }

        #information-widgets-right > .services-group {
          width: auto !important;
          min-width: 0 !important;
          height: 100% !important;
          flex: none !important;
        }

        #information-widgets-right .services-group .services-list {
          display: grid !important;
          grid-template-columns: repeat(4, minmax(0, 1fr)) !important;
          gap: 12px !important;
          height: 100% !important;
          margin: 0 !important;
        }

        #information-widgets-right .services-group .service-card {
          width: auto !important;
          min-width: 0 !important;
          height: 100% !important;
          margin: 0 !important;
        }

        #information-widgets-right .service-description {
          display: none !important;
        }

        #information-widgets-right .service-title {
          min-height: 42px !important;
          align-items: center !important;
          border-bottom: 1px solid rgba(148, 163, 184, 0.16);
        }

        #information-widgets-right .service-icon {
          width: 2.5rem !important;
        }

        #information-widgets-right .service-icon > div {
          width: 24px !important;
          height: 24px !important;
        }

        #information-widgets-right .service-name {
          padding: 0.5rem 0.25rem !important;
        }

        #information-widgets-right .service-container {
          height: calc(100% - 42px) !important;
        }

        #information-widgets-right .service-block {
          background: transparent !important;
          border-radius: 0 !important;
          border-left: 1px solid rgba(148, 163, 184, 0.16);
          margin: 0 !important;
          padding: 0.5rem 0.3rem !important;
        }

        #information-widgets-right .service-block:first-child {
          border-left: 0 !important;
        }
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
        try {
          document.querySelectorAll('link[href*="custom.css"]').forEach((link) => {
            const url = new URL(link.href, window.location.origin);
            url.searchParams.set("v", String(Date.now()));
            link.href = url.toString();
          });
        } catch (_) {}
        // Click the resources box (CPU/RAM/disk/uptime) to expand/collapse detail row.
        // Delegated on document so it keeps working across React re-renders/refreshes.
        try {
          document.addEventListener("click", (event) => {
            const box = event.target.closest(".widget-container");
            if (box && box.querySelector(".information-widget-resource")) {
              box.classList.toggle("resources-expanded");
            }
          });
        } catch (_) {}
        // Relocate the "System" services group (Host + network + both GPU tiles) into the
        // top info-widgets row, in the slot the search widget used to occupy.
        // Re-run via MutationObserver in case of re-renders; a dataset flag on
        // the (now-relocated) node keeps this idempotent.
        try {
          const moveSystemGroup = () => {
            const heading = Array.from(document.querySelectorAll(".service-group-name")).find(
              (candidate) => candidate.textContent.trim() === "System",
            );
            if (!heading) return;
            const group = heading.closest(".services-group");
            const target = document.querySelector("#information-widgets-right") || document.querySelector("#widgets-wrap");
            if (!group || !target || group.dataset.movedToWidgets) return;
            group.dataset.movedToWidgets = "1";
            target.appendChild(group);
          };
          moveSystemGroup();
          new MutationObserver(moveSystemGroup).observe(document.body, { childList: true, subtree: true });
        } catch (_) {}
      })();
    '';
  };

  # Homepage has no bind-address option and listens on all interfaces, unlike the localhost-only
  # AI services. Port 8083 stays closed; Tailscale clients reach it via Serve on :443.
}
