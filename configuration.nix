{ config, pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

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

  # Networking
  networking = {
    hostName = "nixos";
    networkmanager.enable = true;
    firewall.interfaces.tailscale0.allowedTCPPorts = [ 22 ];
  };

  virtualisation.docker.enable = true;

  # User and packages
  users.users.rileyt = {
    isNormalUser = true;
    description = "riley thomason";
    extraGroups = [
      "docker"
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
}
