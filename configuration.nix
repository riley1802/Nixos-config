{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./llama-cpp.nix
    ./n8n.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Chicago";
  i18n.defaultLocale = "en_US.UTF-8";

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.allowUnfree = true;

  hardware.enableRedistributableFirmware = true;
  hardware.graphics.enable = true;
  hardware.nvidia = {
    open = false;
    modesetting.enable = true;
    powerManagement.enable = false;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };

  services.xserver = {
    enable = true;
    videoDrivers = [ "nvidia" ];
    xkb = {
      layout = "us";
      variant = "";
    };
    desktopManager.cinnamon.enable = true;
    displayManager.lightdm.enable = true;
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  programs.dconf.enable = true;
  programs.kdeconnect.enable = true;
  programs.steam.enable = true;

  services.tailscale.enable = true;
  virtualisation.docker.enable = true;

  users.users.rileyt = {
    isNormalUser = true;
    description = "riley thomason";
    extraGroups = [
      "docker"
      "networkmanager"
      "wheel"
    ];
  };

  systemd.tmpfiles.rules = [
    "d /home/rileyt/.local/share/Steam 0755 rileyt users - -"
    "d /home/rileyt/.local/share/unsloth 0755 rileyt users - -"
  ];

  environment.systemPackages = with pkgs; [
    code-cursor
    git
    google-chrome
    spotify
    vscodium
  ];

  system.stateVersion = "26.05";
}
