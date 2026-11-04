# Lessons

Each entry: what went wrong, and what resolved it.

Taken from the saved Cursor chats on this computer, 2026-06-29 through 2026-11-03 (99 chats). An entry marked **historical** describes a setup that was later removed. Leave it removed unless Riley asks for it again. Standing rules from these entries live in `nix-agent.md`.

## Changing the system

- **Wrong:** New `.nix` files were edited and then evaluated, and the flake reported them missing.
  **Resolved:** The flake only sees git-tracked files. Stage the new file before `nix flake check` or `nix build`. `nixctl` stages on apply. (2026-06-29, d4e585e0; repeated through 2026-11-03)

- **Wrong:** `sudo nixos-rebuild` from an agent shell stopped with "a password is required".
  **Resolved:** Root work goes through `pkexec`. `sudo` has no TTY here. (2026-07-02, db4ce5db; written into `agent.md` 2026-11-03)

- **Wrong:** `pkexec nixos-rebuild switch --flake .#nixos` failed because pkexec's working directory was root's home.
  **Resolved:** Use the absolute flake path `/etc/nixos#nixos`. (2026-07-18, 5f219270)

- **Wrong:** `pkexec` could not find `jq` or `wg` because it clears `PATH`.
  **Resolved:** `pkexec env "PATH=$PATH" …`, or call the binary under `/run/current-system/sw/bin`. (2026-10-28, 0ea4217b)

- **Wrong:** Bare `nix fmt` (no path) sat at 0% CPU for 8–15 minutes.
  **Resolved:** `nix fmt .` or `nix fmt path/to/file.nix`. (2026-07-04, aec02147)

- **Wrong:** `nix fmt` turned a valid file into a syntax error by rewriting a `''` string that contained another `''`.
  **Resolved:** Keep shell snippets from containing the Nix string delimiter. Evaluate again after formatting. (2026-07-18, 21701a1f)

- **Wrong:** Splicing `${lib.optionalString ... '' "$cmd" ''}` onto the end of a shell line made `tailscale serve` fail with "invalid number of arguments", and `nixctl apply` rolled the generation back.
  **Resolved:** A `''` string drops its first newline, so the next command was glued to the previous one. Put each optional command on its own line. (2026-11-04)

- **Wrong:** A config was built and the service still did not exist. The browser got connection refused.
  **Resolved:** Build and eval do not switch the running system. Apply (`nixctl apply`, or the one-time `pkexec nixos-rebuild switch` before nixctl existed). (2026-06-29, 6a459f87)

- **Wrong:** `nixctl apply` stopped before switching because the privileged helper could not run.
  **Resolved:** Retry the privileged step with `pkexec systemd-run` and a `PATH` that includes `/run/wrappers/bin:/run/current-system/sw/bin`. Read `RESULT:` before assuming the system changed. (2026-11-03, aa9849f0)

- **Wrong:** `switch` reported failure while reloading the game-drive mount, and it looked like a bad generation.
  **Resolved:** ntfs-3g cannot remount a live volume. The mount stayed up and the generation was still good. (2026-10-29, 38d03ad3)

- **Wrong:** `reboot` from a shell was refused: "Operation inhibited by user session".
  **Resolved:** Cinnamon's logind inhibitor. Use the Cinnamon menu, or `systemctl reboot -i`. (2026-10-29, 38d03ad3)

- **Wrong:** `/etc/nixos` was root-owned, so the agent wrote nothing and a rebuild left the old desktop in place.
  **Resolved:** `chown` the tree to `rileyt` so the working copy is editable. Apply after the files actually exist. (2026-06-29, d4e585e0)

- **Wrong:** `services.displayManager.gdm.wayland = true` was rejected on NixOS 26.05 / GNOME 50.
  **Resolved:** Drop the option. GDM already defaults to Wayland. **Historical:** the desktop is Cinnamon on X11 now. (2026-06-29, d4e585e0)

- **Wrong:** Two `systemd.services` assignments in one attrset in `modules/services/arr/media.nix` failed evaluation.
  **Resolved:** One attrset, with each unit's settings inside it. Nix does not merge duplicate keys inside a single set. (2026-11-03, 11e74586)

- **Wrong:** A file move looked behavior-preserving while unit order changed the system derivation.
  **Resolved:** Compare the old and new system derivations with cfgdiff, and use `lib.mkAfter` where order matters, until the derivations match. (2026-11-03, 11e74586)

## Git, GitHub, and secrets

- **Wrong:** `git commit` failed with "Please tell me who you are".
  **Resolved:** Riley sets `user.name` and `user.email`. Agents do not set git config. (2026-06-29, c4c9e29e)

- **Wrong:** Push of a workflow file was rejected because the GitHub token lacked the `workflow` scope.
  **Resolved:** `gh auth refresh --scopes workflow`, then push. (2026-06-29, c4c9e29e)

- **Wrong:** CI failed because `hardware-configuration.nix` was not formatted.
  **Resolved:** Format, commit, push. The check is `nix fmt -- --check .`. (2026-06-29, c4c9e29e)

- **Wrong:** An agent accepted a Discord bot token in chat, and later a Tailscale auth key was pasted.
  **Resolved:** Refuse the paste. Secrets are edited with `agenix -e` on the machine. Encrypted `.age` files may be committed. Plaintext may not. (2026-07-04, 37dd909c; 2026-06-29, 6a459f87)

- **Wrong:** `agenix -e` with a non-interactive `EDITOR=cp` wrote an empty secret.
  **Resolved:** Pipe the contents into agenix from a file under `/run/user`, not from the chat. (2026-07-22, b31c66c4)

- **Wrong:** `agenix -e` from the wrong directory did not find the rules.
  **Resolved:** `cd /etc/nixos && AGENIX_RULES=secrets/secrets.nix agenix -e …`. "Files differ" means the re-encrypt worked. (2026-10-31, a0c00a05)

- **Wrong:** A secret path in a nested module pointed at `modules/secrets/` instead of the repo `secrets/` directory, and the `.age` file was untracked so the flake never loaded it.
  **Resolved:** Path relative to the module file, and `git add` the encrypted file. **Historical** for Hermes; the path rule still applies. (2026-07-04, 37dd909c)

- **Wrong:** `secrets/result` (a Nix symlink) was going to be committed.
  **Resolved:** Leave it untracked. Commit only the `.age` files. (2026-10-31, a0c00a05)

- **Wrong:** Restarting a service after editing an `.age` file left it on the old decrypted file (`KUMA_USERNAME` missing).
  **Resolved:** agenix decrypts at activation. Apply the system. A restart does not re-decrypt. (2026-07-18, 88cacd02)

- **Wrong:** Activation failed with "invalid key" for Tailscale because the agenix auth key was a placeholder.
  **Resolved:** Replace the key with `agenix -e` and rebuild. Tailscale on this machine is now a manual login, with no auth key in the config. (2026-06-29, 6a459f87)

## Desktop, GPU, and the mouse

- **Wrong:** Ghostty's Home Manager module left `systemd.enable` on, so the GNOME icon launched with `--initial-window=false` and appeared to do nothing.
  **Resolved:** `programs.ghostty.systemd.enable = false`. **Historical:** Ghostty was removed. (2026-07-04, aec02147; removed 2026-07-06, 47189dd1)

- **Wrong:** A Tauri tray around Homepage crashed on this dual-NVIDIA machine (`Error 71` / DMABUF), then showed a window whose clicks did nothing.
  **Resolved:** WebKitGTK plus the NVIDIA driver. Workarounds (`WEBKIT_DISABLE_DMABUF_RENDERER`, destroying the webview instead of hiding it) were not enough. Riley removed Tauri and kept a browser page. **Historical.** (2026-07-18, efafe73f, 4a7c8792, b6e5688a)

- **Wrong:** Homepage looked unchanged after a config edit because the tray WebView had cached the old page, and `:has()` CSS did not work in that WebKit.
  **Resolved:** Cache-bust, avoid `:has()`, and restart the client. **Historical** with the tray. A browser hard-refresh is the remaining case. (2026-07-18, 92414ae9)

- **Wrong:** Chrome movie playback tore. Turning on "GPU acceleration" did not fix it.
  **Resolved:** Decode (VA-API / NVDEC) and the X11 compositor are separate. Mixed 144 Hz and 60 Hz panels made it worse. `ForceFullCompositionPipeline` was tried. A later cleanup set NVIDIA `videoAcceleration = false` when Riley asked to drop the VA-API driver. Log out and back in after a driver change. (2026-09-07, ad675817; 2026-09-26, d3d0c0e0)

- **Wrong:** The pointer felt laggy. Forcing the composition pipeline and disabling VRR did not fix it. The right-hand Samsung was still at 60 Hz.
  **Resolved:** Both 2560×1440 panels at 144 Hz (`xrandr` and `cinnamon-monitors.xml`). Commit `2944185`. (2026-10-29, 5e88c1a8)

- **Wrong:** The pointer stuttered again and the first suspects were OpenLogi, the RTX 3050 clock, qBittorrent reads, and the composition pipeline.
  **Resolved:** The desktop was stalling on a saturated USB game drive while Jellyfin transcoded. Riley then said the USB receiver dongle was the actual fix, and the other changes were reverted. (2026-11-03, aa9849f0)

- **Wrong:** KDE Connect on Cinnamon had no tray icon with `programs.kdeconnect.enable` alone.
  **Resolved:** An XDG autostart entry for `org.kde.kdeconnect.nonplasma`. (2026-09-27, 09d88fb4)

- **Wrong:** "Balena Etcher" was heard as a request to add a user.
  **Resolved:** It was a USB flasher. `nix run nixpkgs#popsicle`. No config change. (2026-07-26, 02064514)

## Disks and storage

- **Wrong:** `/vault/media` never appeared. systemd logged "unsafe path transition".
  **Resolved:** `/vault` was owned by `rileyt`. tmpfiles will only create directories under a `root:root` parent. `chown root:root /vault` (leave `home-backup` alone) and order tmpfiles after `vault.mount`. (2026-10-28, 0ea4217b)

- **Wrong:** The file manager showed `/vault` as 0 B free of ~938 GiB, read as an empty or unmounted disk.
  **Resolved:** The ext4 filesystem was full. The leftover blocks were root's 5% reserve, which qBittorrent and the other services cannot use. (2026-10-31, 861b5676)

- **Wrong:** Download and library folders looked like they used twice the disk.
  **Resolved:** Sonarr and Radarr hardlink. Two paths, one inode. (2026-10-31, 861b5676)

- **Wrong:** The kernel ntfs3 mount of the game drive, with one uid for the volume, let the arr users read `/mnt/game-drive/old stuff`.
  **Resolved:** ntfs-3g mounted so the volume looks rileyt-only, and a bindfs view exposes only the media tree at the paths the apps already had. (2026-10-31, 861b5676)

- **Wrong:** Sonarr warned that qBittorrent's `/vault/media/downloads/tv` was invisible, and Lidarr said the same about `/vault/media/downloads/music`. Imports failed with EACCES. Sonarr also offered an update to 4.0.20.3014.
  **Resolved:** `mirror-only=@media` kept the on-disk group `users` and cleared permissions for the service accounts. `force-group=media` makes the view mode `0770` and group `media`, which is the group those services run as. Sonarr comes from the unstable pin, where the package is 4.0.20.3014. (2026-11-04)

- **Wrong:** Ordering a unit on `mnt-game-drive.mount` left the media stack down.
  **Resolved:** The hyphen in the path is escaped: `mnt-game\x2ddrive.mount`. (2026-10-31, 861b5676)

- **Wrong:** Immich was pointed at the NTFS game drive, and files dropped into `/vault/immich` did not show up in the app.
  **Resolved:** The library stays on ext4 `/vault/immich`. Files the app should see are an external library scan of a directory owned by `immich`, after a copy, not a chmod on NTFS (ntfs-3g ignores chmod). (2026-10-31, b40e7bbb, 861b5676)

- **Wrong:** Steam games lived under the Nix store and vanished across rebuilds.
  **Resolved:** A persistent `/games/steam-library` via tmpfiles, then add that path in Steam's storage settings. (2026-06-29, 72c2d78c)

## Network, SSH, and Tailscale

- **Wrong:** OpenSSH was enabled and port 22 was open on the LAN.
  **Resolved:** `openFirewall = false`, and TCP 22 allowed only on `tailscale0`. (2026-06-29, 6a459f87)

- **Wrong:** `ssh laptop` used `rileyt`. The Mint account is `riley` on `rileys-minty`.
  **Resolved:** `ssh riley@rileys-minty`. From the laptop, `ssh rileyt@nixos` after the key is in `authorized_keys`. (2026-09-26, 05b363c5)

- **Wrong:** Proton on the Mint machine could not resolve `nixos.local`.
  **Resolved:** Proton's DNS does not do mDNS. Use the LAN IP. **Historical** for the Rust server, still true for Proton. (2026-09-24, a34bc072)

- **Wrong:** `%command%` was pasted into a terminal on Mint (`exec: %command%: not found`).
  **Resolved:** That token is a Steam launch option, not a shell command. (2026-09-24, a34bc072)

- **Wrong:** Each service shipped its own Tailscale Serve unit. On boot they overwrote each other and routes disappeared.
  **Resolved:** One Serve unit that writes every route. (2026-10-29, 38d03ad3)

- **Wrong:** `services.tailscale.serve` was used for HTTPS and did not terminate TLS. Serve was also disabled in the Tailscale admin, so certificate requests failed.
  **Resolved:** Enable Serve in the admin once. The module runs `tailscale serve --bg --https=…` against a loopback port. (2026-07-18, ae90f82f)

- **Wrong:** n8n listened on `0.0.0.0:5678` while Serve also bound port 5678.
  **Resolved:** The app listens on `127.0.0.1`. Serve owns the tailnet port. (2026-07-18, ae90f82f)

- **Wrong:** Homepage tiles used `http://127.0.0.1:…`. They worked on this desktop and failed from the phone.
  **Resolved:** Loopback is the server's loopback. Remote links use the MagicDNS HTTPS URL. Health checks stay on loopback. (2026-07-18, c8610e6b)

- **Wrong:** `http://nixos.taile9f484.ts.net:8081` timed out in Chrome.
  **Resolved:** Chrome upgrades `*.ts.net` to HTTPS (HSTS) and nothing was listening with a certificate on that raw port. Serve provides the certificate. (2026-10-28, 8e93deae)

- **Wrong:** MagicDNS names did not resolve on the desktop. dnsproxy forwarded everything to Cloudflare, and Chrome secure DNS did the same.
  **Resolved:** dnsproxy sends `taile9f484.ts.net` to `100.100.100.100`. A managed Chrome policy sets secure DNS off. Tailscale's own DNS stays off so it does not replace dnsproxy. (2026-10-28, 8e93deae)

- **Wrong:** A service was configured and the browser still got connection refused, because switch had not been run, or the port was only on loopback with no `tailscale0` firewall entry.
  **Resolved:** Apply, bind loopback, allow the port on `tailscale0` only. (2026-10-28, 3a644271)

- **Wrong:** Months of uptime were treated as proof the stack survived a reboot. It had not been tested since September.
  **Resolved:** Serve in one unit, mount timeouts, service ordering (dnsproxy before `network-online`, qBittorrent and Prowlarr after `tailscale0`, llama after the NVIDIA nodes), and a boot fallback timer. (2026-10-29, 38d03ad3)

## llama.cpp and models

- **Wrong:** Stock `pkgs.llama-cpp` from NixOS 26.05 (build ~9190) could not load LFM3, and the stock module sandbox blocked CUDA.
  **Resolved:** `packages/llama-cpp.nix` builds v0.8.0 with CUDA. Custom units, with the sandbox relaxed on the GPU service. (2026-10-28, 8e93deae)

- **Wrong:** Both GPUs were treated as interchangeable. The 3050 drives the displays. A 64k context on the 3050 OOM'd. A 128k Gemma context OOM'd. A 131k Qwen context OOM'd.
  **Resolved:** VL is pinned to the 3050 by GPU UUID. The 1.7B server is refused every GPU and runs on CPU. The 1660 stays idle. Context stays inside the 6 GB card that is also compositing the desktop. (2026-10-28, 8e93deae; 2026-10-30, 318e479e)

- **Wrong:** llama-server's default parallel slots divided the context, so 64k was not 64k per client.
  **Resolved:** `--parallel 1`. (2026-09-06, 209ba186)

- **Wrong:** Hugging Face XET left `.incomplete` blobs, then the server reported "failed to load model".
  **Resolved:** `HF_HUB_DISABLE_XET=1` and `HF_HUB_ENABLE_HF_TRANSFER=0`. (2026-07-22, b31c66c4; 2026-07-23, 2c580464)

- **Wrong:** A stray `llama-cli` held VRAM and the next server CUDA-OOM'd on device 0.
  **Resolved:** Stop the stray process before measuring. The desktop compositor is already using the 3050. (2026-06-29, 6a459f87)

- **Wrong:** Unsloth Studio launched at ~55k context and ran at about 3 tok/s, with the 1660 idle and the CPU pegged.
  **Resolved:** Cap the wrapper at 8192 context with q8_0 KV. Vision (`UNSLOTH_ALLOW_MMPROJ=1`) stayed on because Riley required it. (2026-07-22, b31c66c4)

- **Wrong:** The Homepage links for Whisper and Piper looked like broken web UIs, and llama's UI failed while several models were loaded (`cudaMalloc failed`).
  **Resolved:** Whisper and Piper are not clickable pages. llama got `--models-max 1`. **Historical** for that Homepage layout. (2026-07-18, 1e7dc499)

- **Wrong:** A whisper service called `ffmpeg` and got "command not found" even with a systemd `Path=`.
  **Resolved:** The shell did not see `Path=`. Put ffmpeg on the unit's `Environment` PATH. (2026-07-04, bcef5447)

## Media stack and PIA

- **Wrong:** The whole desktop was put on the VPN. Throughput dropped from ~28 MB/s to ~1.1 MB/s, and PIA's hostname scripts failed because DNS was reset.
  **Resolved:** Split tunnel. qBittorrent uses the `pia` interface and routing table 51820. The desktop stays on the LAN. Tailscale is not the torrent VPN. (2026-10-28, 0ea4217b)

- **Wrong:** Prowlarr was marked for the VPN but its packets left with the LAN source address and timed out.
  **Resolved:** MASQUERADE on `pia` for the mark. Do not add an IPv6 REJECT on that cgroup; it hung .NET indexers. (2026-10-28, 0ea4217b)

- **Wrong:** `RestrictNetworkInterfaces=lo pia tailscale0` logged "Couldn't find index of network interface 'pia', ignoring" and traffic died.
  **Resolved:** The index is fixed when the process starts. Start Prowlarr and qBittorrent after `pia-wireguard`, and restart them when the tunnel recreates `pia`. (2026-10-28, d7711f0f)

- **Wrong:** A port-forward check read the last three journal lines and reported failure.
  **Resolved:** The success line was one line earlier. Read more of the unit log. (2026-10-28, d7711f0f)

- **Wrong:** A download at ~0.13 MB/s was blamed on the VPN. The tunnel itself could do ~75 MB/s.
  **Resolved:** qBittorrent queue settings. A stalled torrent was holding the active slot. (2026-10-28, 0ea4217b)

- **Wrong:** The qBittorrent module's `ExecStartPre` rewrote the config on every start, so a WebUI password set in the UI disappeared.
  **Resolved:** Persist `Password_PBKDF2` and restore it from the module. Set the password through the API. The session cookie is `QBT_SID_8080`, not `SID`. (2026-10-28, 0ea4217b)

- **Wrong:** Radarr could not see `downloads/movies`. Group `media` and mode `2775` on the parent were not enough.
  **Resolved:** The category directories need the same setgid and group. qBittorrent is in group `media` with `UMask=0002`. (2026-10-28, 0ea4217b)

- **Wrong:** `UMask=0002` left Sonarr's database and qBittorrent's resume files world-readable.
  **Resolved:** A one-time chmod of those trees to `700`/`600`, plus a `preStart` that keeps them there. (2026-10-28, c6e1ac1a)

- **Wrong:** Lidarr offered an in-app update. Installing it would not replace the Nix store path and would drift from the pinned tarball.
  **Resolved:** `LIDARR__UPDATE__MECHANISM=external`. The package is the official 3.1.6.5079 tarball in `packages/lidarr.nix`. (2026-10-28, 34647357)

- **Wrong:** Prowlarr API automation used `appProfileId` 0, omitted sync categories, and Seerr was pointed at Jellyfin with a bad `urlBase`.
  **Resolved:** `appProfileId = 1`, the sync categories including `8000`, and `urlBase = ""`. (2026-10-28, 0ea4217b)

- **Wrong:** Lidarr reported "connection refused" to `127.0.0.1:8080`.
  **Resolved:** qBittorrent was not running yet. The arr apps use that loopback port and their categories. (2026-10-28, 0ea4217b)

## Other services

- **Wrong:** Homepage linked to nginx `/n8n/`. n8n 2.x referenced assets under `/n8n/` while serving them at `/`, so the browser received HTML instead of JavaScript.
  **Resolved:** No `N8N_PATH`. Loopback plus Tailscale Serve. Health check is `http://127.0.0.1:5678/healthz`. (2026-07-18, ae90f82f)

- **Wrong:** ntfy `base-url` included `/ntfy`. ntfy rejects a path in `base-url`.
  **Resolved:** A path-less URL on its own port. (2026-07-18, 21701a1f)

- **Wrong:** Homepage `allowedHosts` did not include the MagicDNS name and the real listen port, so the proxied Host header was rejected.
  **Resolved:** Allow the MagicDNS host and the loopback host:port. **Historical** with Homepage. The same header check applies to any app that has an allow-list. (2026-07-18, c8610e6b)

- **Wrong:** Portainer `extraOptions` included `--restart=unless-stopped`, which fights oci-containers' `--rm`.
  **Resolved:** Drop the Docker restart flag. systemd restarts the unit. (2026-07-18, 21701a1f)

- **Wrong:** An nginx `/portainer/` proxy kept the prefix, and a setup timeout redirected to `/timeout.html`, which Homepage then 404'd.
  **Resolved:** Proxy to the backend root, and finish setup inside the window. **Historical:** nginx and that Portainer layout are gone. (2026-07-18, 21701a1f)

- **Wrong:** An n8n Postgres oneshot ran `PASSWORD :'pass'` inside `psql -c`, and Postgres saw the literal `:'pass'`.
  **Resolved:** Put the password in the `-c` string. The charset has to be safe, and the Nix `''` quoting has to survive `nix fmt`. (2026-07-18, 21701a1f)

- **Wrong:** Default `pkgs.netdata` returned "File does not exist, or is not accessible" for the UI.
  **Resolved:** Use the `netdataCloud` package and open `/v3`. (2026-10-31, 785edbdd)

- **Wrong:** A Netdata swap alarm was read as a broken Netdata.
  **Resolved:** Swap was actually full (Jellyfin, llama, and the rest). The alarm was right. (2026-10-31, 785edbdd)

- **Wrong:** n8n was given two llama URLs only through environment variables. n8n 2.x does not wire OpenAI-compatible credentials that way.
  **Resolved:** Create the credential in the n8n UI: `http://127.0.0.1:8082/v1`, model name, dummy key `local`. The age file is for the servers and Open WebUI, not for n8n. (2026-10-29, 068dc80a)

- **Wrong:** llama-server was reachable on the tailnet with no API key.
  **Resolved:** `secrets/llama-api-key.age` and `--api-key-file` on both servers. (2026-10-31, a0c00a05)

- **Wrong:** Homarr tiles were edited in the Nix module and did not change.
  **Resolved:** The board lives in `/var/lib/homarr`. (2026-10-30, d0cacf4c)

- **Wrong:** Homarr showed Open WebUI, both llama servers, n8n, ntfy, Uptime Kuma, qBittorrent, Prowlarr, Seerr, and Jellyfin offline.
  **Resolved:** The container was pinging its own loopback, or the bridge firewall was dropping the check. Docker's `host-gateway` is `docker0` (`172.17.0.1`), so `host.docker.internal` is pinned to the Homarr gateway `172.30.88.1`. Proxies there cover the loopback apps. The firewall, qBittorrent, and Prowlarr accept the bridge, and Prowlarr's reply to that subnet stays off the VPN. Ping URLs are `http://host.docker.internal:PORT`. (2026-11-03)

- **Wrong:** Uptime Kuma monitors were expected to come only from git.
  **Resolved:** They live in `/var/lib/private/uptime-kuma/kuma.db`. Stop the service before writing the sqlite file. (2026-10-29, 068dc80a)

- **Wrong:** Flashforge's desktop app, unpacked and run directly, could not find webkit, curl's OpenSSL, or GBM/EGL.
  **Resolved:** A Nix package with those libraries on the loader path. **Historical:** the Flashforge module was later removed; Orca-Flashforge user profiles were kept. (2026-09-07, 5ac622da; 2026-09-26, d3d0c0e0)

- **Wrong:** GitNexus indexed the repo as `Nixos-config` while the tools looked up `nixos` (the directory name).
  **Resolved:** `gitnexus analyze --index-only --name nixos`. (2026-08-09, 1623b5f1)

- **Wrong:** A shell script on NixOS called bare `nft` or `jq` and failed.
  **Resolved:** Use `/run/current-system/sw/bin` or `nix shell`. The agent environment does not have a normal user PATH. (2026-09-24, a34bc072)

- **Wrong:** `git commit` / `git push` happened when Riley had not asked, and a push went out from a feature branch that was not `main`.
  **Resolved:** Commit when asked. For this host, `main` is the branch that matches the machine. `nixctl apply` is the exception: it commits locally and does not push. (2026-09-26, d3d0c0e0)

## Removed on purpose

These were installed, broke or got in the way, and Riley had them taken out. Do not put them back unless he asks in the current chat.

- **Raspberry Pi host and scripts** (2026-07-03, 86dc55ce). The Pi 4 USB boot of a generic NixOS image died after stage 1/2. The Pi OS bridge plus a watcher that re-ran phase 1 every few minutes killed the kernel compile over and over. A full aarch64 image built on this desktop ran under qemu and pegged the CPUs for hours; a leftover `qemu-aarch64` was still doing that after the Pi was abandoned. The prebuilt SD image got further (headless SSH worked; GNOME on the Pi 4 boot-looped in Wayland). Riley then asked for every Pi trace removed from this repo. Kill stray `qemu-aarch64` if one appears.

- **Hermes and Ghostty** (2026-07-06, 47189dd1). Hermes' `hermes setup` writes `/var/lib/hermes`, and Nix merges over it, so stale keys survived a config edit until the runtime file was removed and the system was rebuilt. WhatsApp was enabled before `bridge.js` existed and the gateway exited 78. Discord and Spotify needed agenix, not tokens in chat.

- **Homepage, its Tauri shell, and World Monitor** (Homepage removed 2026-10-31, 7426e55b; Tauri 2026-07-18, b6e5688a; World Monitor 2026-07-18, 93a9d796). Homarr is the board. Removing Homepage meant the module, the flake import, the Serve port, the firewall entry, the desktop launcher, and the age secret. Wiping the runtime directory was a separate step Riley confirmed.

- **GitLab** (removed 2026-10-07, c3d1b913). First login is username `root` and a generated password, not an email signup. `.local` hostnames collided with mDNS. An activation script called `cmp` without `diffutils` on `PATH`. The runner could not be a `DynamicUser` and also a shell executor.

- **Rust dedicated server, llama.cpp (that generation), n8n (that generation), FlashPrint** (2026-09-26, d3d0c0e0). Riley asked for a clean desktop and named what to keep. "Factory reset" meant that list, not a console-only machine. The Rust furnace plugin had to hook `OnOvenCook`; editing the shared item definitions did nothing in game. Those services were added again later, on purpose, in the October stack.

- **Goose** (2026-06-29, 6a459f87). Home Manager collided with files already in `~/.config/goose`. The launcher needed `kgx` instead of `gnome-terminal`, and the Electron build needed `libEGL`. Riley dropped it.

- **September wipe** (2026-09-05, fff2724a). Home was emptied while Cinnamon and Cursor were still running, so the delete was partial. Switch to the new generation and push to GitHub before deleting home, or git credentials and the rollback generation go with it. The wipe did not reformat the disk and did not change `stateVersion` or the password.

## How the agent work went wrong

- **Wrong:** A large install (Rust server, GitLab, a wipe, a model swap) proceeded on assumed hostnames, ports, and what "factory" meant.
  **Resolved:** Ask one decision at a time before editing. Riley said "don't assume anything, ask me first" on those jobs. (2026-09-24, a34bc072; 2026-09-27, 00b8f72b)

- **Wrong:** An MCP server and a stack of files were about to be installed after the research, before Riley had agreed.
  **Resolved:** He cancelled the MCP install. Research, summarize, then ask before the edit, on work that is hard to undo. (2026-07-04, 7bdb9e02, a5c73f2d)

- **Wrong:** Book-derived agent rules overrode the NixOS module layout.
  **Resolved:** For this repo, the nixos-managing skill and these two files win. (2026-07-04, ea39f109)

- **Wrong:** A background subagent did the work where Riley could not see it, and the assistant said an app was running when the window was not there.
  **Resolved:** He asked to stop the hidden agent. Check the process and the window before claiming it is up. (2026-07-04, bcef5447)

- **Wrong:** Docs described a flat config after the tree had become `hosts/` plus `modules/`, and docs were left for a later pass.
  **Resolved:** Update `README.md`, this file, `nix-agent.md`, and the module comment in the same step as the change. (2026-07-04, 5fe052c5; 2026-11-03, b3baf786)

- **Wrong:** `nixos-managing` was copied into a second skills directory.
  **Resolved:** One tree at `/etc/nixos/agent/nixos-managing`, with symlinks into Cursor's skill folders, so the copies cannot drift. (2026-11-03, c6e1a544)
