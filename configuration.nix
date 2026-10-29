{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./pia-wireguard.nix
    ./media-stack.nix
    ./uptime-kuma.nix
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
      screenSection = ''
        Option "ForceFullCompositionPipeline" "true"
      '';
      xkb = {
        layout = "us";
        variant = "";
      };
      desktopManager.cinnamon.enable = true;
      displayManager.lightdm.enable = true;
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

  virtualisation.docker.enable = true;

  # The disk labeled "vault". Existing backups stay where they are.
  fileSystems."/vault" = {
    device = "/dev/disk/by-uuid/f279aaed-ae58-47e8-9629-d6654c68a0e9";
    fsType = "ext4";
  };

  users.groups.media = { };
  users.users.qbittorrent.extraGroups = [ "media" ];
  systemd.services.qbittorrent.serviceConfig.UMask = "0002";
  systemd.services.systemd-tmpfiles-setup.after = [ "vault.mount" ];
  systemd.services.systemd-tmpfiles-resetup.after = [ "vault.mount" ];
  # The NixOS module rewrites qBittorrent.conf on every start. Keep the WebUI
  # password hash beside that file so it is not committed to Git.
  systemd.services.qbittorrent.preStart = ''
    set -euo pipefail
    conf=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
    saved=/var/lib/qBittorrent/qBittorrent/config/webui-password-line
    # The client rewrites its config world-readable. Keep the directory private.
    chmod 700 /var/lib/qBittorrent/qBittorrent /var/lib/qBittorrent/qBittorrent/config
    umask 077
    if [[ -f $conf ]] && grep -q 'Password_PBKDF2=' "$conf"; then
      grep 'Password_PBKDF2=' "$conf" > "$saved"
    fi
  '';
  systemd.services.qbittorrent.serviceConfig.ExecStartPre = pkgs.lib.mkAfter [
    (pkgs.writeShellScript "qbittorrent-restore-webui-password" ''
      set -euo pipefail
      conf=/var/lib/qBittorrent/qBittorrent/config/qBittorrent.conf
      saved=/var/lib/qBittorrent/qBittorrent/config/webui-password-line
      if [[ -s $saved ]] && ! grep -q 'Password_PBKDF2=' "$conf"; then
        printf '\n[Preferences]\n' >> "$conf"
        cat "$saved" >> "$conf"
      fi
    '')
  ];
  systemd.tmpfiles.settings.media =
    let
      mediaDirectory = {
        mode = "2775";
        user = "root";
        group = "media";
      };
    in
    pkgs.lib.genAttrs [
      "/vault/media"
      "/vault/media/downloads"
      "/vault/media/downloads/incomplete"
      "/vault/media/library"
      "/vault/media/library/tv"
      "/vault/media/library/movies"
      "/vault/media/library/music"
    ]
      (_path: {
        "d" = mediaDirectory;
      });

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

  environment.systemPackages = with pkgs; [
    code-cursor
    git
    google-chrome
    htop
    spotify
  ];

  # Keep this at the version used for the first installation.
  system.stateVersion = "26.05";

  # Encrypted DNS: a local forwarder on 127.0.0.1 that sends lookups
  # out over TLS (port 853), because plain DNS is blocked for VPN sites.
  services.dnsproxy = {
    enable = true;
    settings = {
      listen-addrs = [ "127.0.0.1" ];
      listen-ports = [ 53 ];
      upstream = [ "tls://1.1.1.1" "tls://1.0.0.1" ];
    };
  };
  networking.nameservers = [ "127.0.0.1" ];
  networking.networkmanager.dns = "none";
}
