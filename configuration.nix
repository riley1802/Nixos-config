{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./pia-wireguard.nix
    ./media-stack.nix
    ./uptime-kuma.nix
    ./llama-cpp.nix
    ./open-webui.nix
    ./n8n.nix
    ./ntfy.nix
    ./immich.nix
    ./homepage.nix
    ./homarr.nix
    ./netdata.nix
    ./tailscale-serve.nix
  ];

  age.secrets."pia-credentials" = {
    file = ./secrets/pia-credentials.age;
    mode = "0400";
    owner = "root";
    group = "root";
  };

  # Boot and regional settings
  boot.loader = {
    systemd-boot.enable = true;
    efi.canTouchEfiVariables = true;
  };

  time = {
    timeZone = "America/Chicago";
  };
  i18n.defaultLocale = "en_US.UTF-8";

  # Nix
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  nixpkgs.config.allowUnfree = true;

  # Hardware and desktop
  hardware = {
    enableRedistributableFirmware = true;
    graphics.enable = true;
    nvidia = {
      open = false;
      modesetting.enable = true;
      powerManagement.enable = false;
      videoAcceleration = false;
      package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };

  services = {
    xserver = {
      enable = true;
      videoDrivers = [ "nvidia" ];
      # Do not set ForceFullCompositionPipeline. It waits for a composed
      # frame before the cursor moves, which shows up as mouse lag.
      # https://download.nvidia.com/XFree86/Linux-x86_64/595.71.05/README/configtwinview.html
      xkb = {
        layout = "us";
        variant = "";
      };
      desktopManager.cinnamon.enable = true;
      displayManager.lightdm.enable = true;
      # The LG 27GL850 is G-SYNC Compatible, and the driver turns variable
      # refresh on for the whole composited desktop. The cursor then waits
      # on that panel. This leaves it off at login.
      displayManager.sessionCommands = ''
        ${config.boot.kernelPackages.nvidiaPackages.stable.settings}/bin/nvidia-settings -a AllowVRR=0
      '';
    };

    pulseaudio.enable = false;
    pipewire = {
      enable = true;
      alsa.enable = true;
      pulse.enable = true;
    };

    tailscale.enable = true;

    # OpenSSH is reachable from the tailnet only.
    openssh = {
      enable = true;
      openFirewall = false;
      settings = {
        AllowUsers = [ "rileyt" ];
        KbdInteractiveAuthentication = false;
        PasswordAuthentication = false;
        PermitRootLogin = "no";
      };
    };
    qbittorrent = {
      enable = true;
      webuiPort = 8080;
      torrentingPort = 53644;
      openFirewall = false;
      extraArgs = [ "--confirm-legal-notice" ];

      serverConfig.BitTorrent.Session = {
        Interface = "pia";
        InterfaceName = "pia";
        DefaultSavePath = "/vault/media/downloads";
        TempPathEnabled = true;
        TempPath = "/vault/media/downloads/incomplete";
        # A torrent under 1 MB/s does not use up a download slot, so a
        # nearly stopped album cannot keep every movie waiting.
        QueueingSystemEnabled = true;
        MaxActiveDownloads = 8;
        MaxActiveUploads = 4;
        MaxActiveTorrents = 16;
        IgnoreSlowTorrentsForQueueing = true;
        SlowTorrentsDownloadRate = 1024;
        SlowTorrentsUploadRate = 10;
        SlowTorrentsInactivityTimer = 60;
      };
    };
  };

  security.rtkit.enable = true;

  programs = {
    dconf.enable = true;
    kdeconnect.enable = true;

    # `ssh laptop` uses the Linux machine already on this tailnet.
    ssh.extraConfig = ''
      Host laptop
        HostName rileys-minty.taile9f484.ts.net
        User riley
    '';
  };

  # The package autostarts kdeconnectd only. Cinnamon needs this
  # indicator entry for the tray icon.
  environment.etc."xdg/autostart/org.kde.kdeconnect.nonplasma.desktop".source =
    "${config.programs.kdeconnect.package}/share/applications/org.kde.kdeconnect.nonplasma.desktop";

  # Networking
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    # KDE Connect stays open for the phone on the home network only.
    firewall =
      let
        kdeConnectPorts = [
          { from = 1714; to = 1764; }
        ];
      in
      {
        allowedTCPPortRanges = pkgs.lib.mkForce [ ];
        allowedUDPPortRanges = pkgs.lib.mkForce [ ];
        interfaces = {
          tailscale0.allowedTCPPorts = [
            22
            8080 # qBittorrent WebUI
            8096
          ];
          enp132s0 = {
            allowedTCPPortRanges = kdeConnectPorts;
            allowedUDPPortRanges = kdeConnectPorts;
            allowedTCPPorts = [ 8096 ];
          };
          pia = {
            allowedTCPPorts = [ 53644 ];
            allowedUDPPorts = [ 53644 ];
          };
        };
      };
  };

  # Docker's own iptables rules bypass the NixOS firewall, so a published
  # port (-p 8000:8000) would otherwise be open on the home network.
  # `-p 0.0.0.0:8000:8000` still opens one on purpose.
  virtualisation.docker = {
    enable = true;
    daemon.settings.ip = "127.0.0.1";
  };

  # The disk labeled "vault". Existing backups stay where they are.
  # The arr files live on the 4 TB game drive. /vault/media is only the
  # view the apps already use, so their saved paths do not change.
  fileSystems."/vault" = {
    device = "/dev/disk/by-uuid/f279aaed-ae58-47e8-9629-d6654c68a0e9";
    fsType = "ext4";
  };

  # NTFS, so the existing "old stuff" directory is not rewritten or
  # repartitioned. The kernel ntfs3 driver left that directory open to
  # other users. ntfs-3g with a uid and dmask shows the whole volume
  # as rileyt-only, and silent ignores chmod on a filesystem that has
  # one mode for every file.
  # https://wiki.nixos.org/wiki/NTFS
  # https://man.archlinux.org/man/ntfs-3g.8.en
  boot.supportedFilesystems = [ "ntfs" ];
  fileSystems."/mnt/game-drive" = {
    device = "/dev/disk/by-uuid/1882D08A82D06DAE";
    fsType = "ntfs-3g";
    noCheck = true;
    options = [
      "nosuid"
      "nodev"
      "uid=1000" # rileyt
      "gid=100"
      "dmask=077"
      "fmask=177"
      "no_def_opts"
      "allow_other"
      "big_writes"
      "silent"
      # USB hard disk. After a shutdown it has to spin up and enumerate.
      # nofail still lets the desktop boot if the cable is unplugged.
      # The timeout is a maximum, not a delay: once the disk is there,
      # the mount proceeds. 15s was short enough that a cold start
      # skipped the mount, and every media service bound to it stayed down.
      "nofail"
      "x-systemd.device-timeout=2min"
      "x-systemd.mount-timeout=3min"
    ];
  };

  # This Seagate enclosure autosuspends. A sleeping disk misses the boot
  # mount and can stall the unmount during shutdown.
  # https://docs.kernel.org/driver-api/usb/power-management.html
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0bc2", ATTR{idProduct}=="ab08", TEST=="power/control", ATTR{power/control}="on"
  '';

  # local-fs already waits up to the device timeout above. If the disk
  # appears after that, start the mount and the services that bind to it.
  # The timer stops once that succeeds, and it gives up after a few tries.
  systemd.services.media-stack-boot = {
    description = "Start media services once the game drive is mounted";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "5min";
      ExecStart = pkgs.writeShellScript "media-stack-boot" ''
        set -euo pipefail
        export PATH=${pkgs.lib.makeBinPath [ pkgs.systemd pkgs.coreutils ]}:$PATH
        attempts=/run/media-stack-boot.attempts
        n=0
        if [[ -f $attempts ]]; then
          n=$(cat "$attempts")
        fi
        n=$((n + 1))
        printf '%s\n' "$n" > "$attempts"
        if (( n > 6 )); then
          echo "game drive is still not mounted; media services stay down" >&2
          systemctl stop media-stack-boot.timer
          exit 1
        fi
        systemctl start "$(systemd-escape -p --suffix=mount /mnt/game-drive)"
        systemctl start vault-media.service media-directories.service
        for s in qbittorrent sonarr radarr lidarr bazarr jellyfin; do
          if systemctl is-enabled --quiet "$s.service" && ! systemctl is-active --quiet "$s.service"; then
            systemctl start "$s.service"
          fi
        done
      '';
    };
  };
  systemd.timers.media-stack-boot = {
    description = "Retry media services until the game drive is mounted";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitInactiveSec = "30s";
      AccuracySec = "5s";
    };
  };

  # bindfs publishes only the media directory to the media group.
  # "old stuff" stays on the NTFS mount, outside this view.
  # Setgid bits do not work on FUSE, so new files are forced into the
  # media group here instead.
  # https://bindfs.org/docs/bindfs.1.html
  systemd.services.vault-media = {
    description = "Media group view of the game drive";
    # The hyphen in /mnt/game-drive is escaped in the systemd unit name.
    wants = [ "mnt-game\\x2ddrive.mount" ];
    after = [ "mnt-game\\x2ddrive.mount" "vault.mount" ];
    bindsTo = [ "mnt-game\\x2ddrive.mount" "vault.mount" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p /vault/media";
      ExecStart = "${pkgs.bindfs}/bin/bindfs -f -o mirror-only=@media,perms=u=rwX:g=rwX:o=,create-for-user=rileyt,create-for-group=media,create-with-perms=u=rwX:g=rwX:o=,chown-ignore,chgrp-ignore,chmod-ignore,multithreaded /mnt/game-drive/media /vault/media";
      Restart = "on-failure";
      RestartSec = "3s";
    };
    unitConfig = {
      StartLimitIntervalSec = "60";
      StartLimitBurst = "5";
    };
  };
  systemd.services.media-directories = {
    description = "Create the shared media directories";
    wants = [ "vault-media.service" ];
    after = [ "vault-media.service" ];
    bindsTo = [ "vault-media.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0775 -o root -g media \
        /vault/media/downloads \
        /vault/media/downloads/incomplete \
        /vault/media/library \
        /vault/media/library/tv \
        /vault/media/library/movies \
        /vault/media/library/music
    '';
  };
  systemd.services.qbittorrent.wants = [ "media-directories.service" ];
  systemd.services.qbittorrent.after = [ "media-directories.service" ];
  systemd.services.qbittorrent.bindsTo = [ "media-directories.service" ];
  systemd.services.sonarr.wants = [ "media-directories.service" ];
  systemd.services.sonarr.after = [ "media-directories.service" ];
  systemd.services.sonarr.bindsTo = [ "media-directories.service" ];
  systemd.services.radarr.wants = [ "media-directories.service" ];
  systemd.services.radarr.after = [ "media-directories.service" ];
  systemd.services.radarr.bindsTo = [ "media-directories.service" ];
  systemd.services.lidarr.wants = [ "media-directories.service" ];
  systemd.services.lidarr.after = [ "media-directories.service" ];
  systemd.services.lidarr.bindsTo = [ "media-directories.service" ];
  systemd.services.jellyfin.wants = [ "media-directories.service" ];
  systemd.services.jellyfin.after = [ "media-directories.service" ];
  systemd.services.jellyfin.bindsTo = [ "media-directories.service" ];
  systemd.services.bazarr.wants = [ "media-directories.service" ];
  systemd.services.bazarr.after = [ "media-directories.service" ];
  systemd.services.bazarr.bindsTo = [ "media-directories.service" ];

  users.groups.media = { };
  users.users.qbittorrent.extraGroups = [ "media" ];
  systemd.services.qbittorrent.serviceConfig.UMask = "0002";
  systemd.services.systemd-tmpfiles-setup.after = [ "vault.mount" ];
  systemd.services.systemd-tmpfiles-resetup.after = [ "vault.mount" ];
  # The NixOS module rewrites qBittorrent.conf on every start. Keep the WebUI
  # username and password hash beside that file so they are not committed
  # to Git.
  systemd.services.qbittorrent.preStart = ''
    set -euo pipefail
    conf=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
    saved=/var/lib/qBittorrent/qBittorrent/config/webui-password-line
    saved_user=/var/lib/qBittorrent/qBittorrent/config/webui-username-line
    # The client rewrites its config world-readable. Keep the directory private.
    chmod 700 /var/lib/qBittorrent/qBittorrent /var/lib/qBittorrent/qBittorrent/config
    umask 077
    if [[ -f $conf ]] && grep -q 'Password_PBKDF2=' "$conf"; then
      grep 'Password_PBKDF2=' "$conf" > "$saved"
    fi
    if [[ -f $conf ]] && grep -q 'WebUI\Username=' "$conf"; then
      grep 'WebUI\Username=' "$conf" > "$saved_user"
    fi
  '';
  systemd.services.qbittorrent.serviceConfig.ExecStartPre = pkgs.lib.mkAfter [
    (pkgs.writeShellScript "qbittorrent-restore-webui-password" ''
      set -euo pipefail
      conf=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
      saved=/var/lib/qBittorrent/qBittorrent/config/webui-password-line
      saved_user=/var/lib/qBittorrent/qBittorrent/config/webui-username-line
      restore=0
      if [[ -s $saved ]] && ! grep -q 'Password_PBKDF2=' "$conf"; then
        restore=1
      fi
      if [[ -s $saved_user ]] && ! grep -q 'WebUI\Username=' "$conf"; then
        restore=1
      fi
      if [[ $restore == 1 ]]; then
        printf '\n[Preferences]\n' >> "$conf"
        if [[ -s $saved ]] && ! grep -q 'Password_PBKDF2=' "$conf"; then
          cat "$saved" >> "$conf"
        fi
        if [[ -s $saved_user ]] && ! grep -q 'WebUI\Username=' "$conf"; then
          cat "$saved_user" >> "$conf"
        fi
      fi
    '')
  ];
  # Only the mountpoint, and not group-writable. The real directories are
  # created after bindfs is up. Creating them here would put them on the
  # vault disk and bindfs would refuse to cover a non-empty directory.
  systemd.tmpfiles.settings.media."/vault/media"."d" = {
    mode = "0755";
    user = "root";
    group = "root";
  };

  # User and packages
  users.users.rileyt = {
    isNormalUser = true;
    description = "riley thomason";
    extraGroups = [
      "docker"
      "media"
      "networkmanager"
      "wheel"
    ];
  };

  # Chrome app windows for the two boards. google-chrome-stable is the
  # package's main program; google-chrome is a symlink to it.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/pkgs/by-name/go/google-chrome/package.nix
  environment.systemPackages = with pkgs; [
    code-cursor
    git
    google-chrome
    htop
    llama-cpp
    spotify
    (makeDesktopItem {
      name = "homepage";
      desktopName = "Homepage";
      comment = "Service board declared in this flake";
      exec = "google-chrome-stable --app=http://127.0.0.1:3010";
      icon = "google-chrome";
      categories = [ "Network" ];
    })
    (makeDesktopItem {
      name = "homarr";
      desktopName = "Homarr";
      comment = "Visual service board";
      exec = "google-chrome-stable --app=http://127.0.0.1:7575";
      icon = "google-chrome";
      categories = [ "Network" ];
    })
  ];

  # Keep this at the version used for the first installation.
  system.stateVersion = "26.05";

  # Encrypted DNS: a local forwarder on 127.0.0.1 that sends lookups
  # out over TLS (port 853), because plain DNS is blocked for VPN sites.
  # Tailscale DNS stays off so it does not replace this forwarder. The
  # tailnet zone is the exception: MagicDNS at 100.100.100.100 answers
  # nixos.taile9f484.ts.net, which 1.1.1.1 does not know.
  # https://github.com/AdguardTeam/dnsproxy#usage
  services.dnsproxy = {
    enable = true;
    settings = {
      listen-addrs = [ "127.0.0.1" ];
      listen-ports = [ 53 ];
      upstream = [
        "[/taile9f484.ts.net/]100.100.100.100:53"
        "tls://1.1.1.1"
        "tls://1.0.0.1"
      ];
    };
  };
  networking.nameservers = [ "127.0.0.1" ];
  networking.networkmanager.dns = "none";
  # This process is the resolver. The module orders it after
  # nss-lookup.target, which is the target other services wait on.
  # Unbound starts before that target instead. NetworkManager's online
  # check also needs a resolver, and it runs before network-online.
  systemd.services.dnsproxy = {
    after = pkgs.lib.mkForce [ "network.target" ];
    before = [
      "nss-lookup.target"
      "NetworkManager-wait-online.service"
    ];
    wantedBy = [
      "nss-lookup.target"
      "network-online.target"
    ];
  };

  # Chrome was set to "secure" DNS through Cloudflare only. That never
  # asks the local forwarder, so tailnet names do not resolve and Chrome
  # reports that the site cannot be reached. Off means Chrome uses the
  # system resolver above.
  # https://chromeenterprise.google/policies/#DnsOverHttpsMode
  environment.etc."opt/chrome/policies/managed/dns.json".text = builtins.toJSON {
    DnsOverHttpsMode = "off";
  };
}
