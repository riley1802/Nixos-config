{ pkgs, ... }:

{
  services.xserver.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;

  programs.dconf.enable = true;

  environment.systemPackages = with pkgs; [
    firefox
    xfce4-screenshooter
  ];
}
