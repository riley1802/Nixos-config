# Raspberry Pi 4 Model B — SD card root. Regenerate disk UUIDs after first
# `nixos-generate-config` on the Pi if you switch away from the installer image.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "usbhid"
    "usb_storage"
    "uas" # USB-attached storage (required for USB root on Pi 4)
    "pcie-brcmstb" # Pi 4 PCIe/USB3 bus
    "reset-raspberrypi" # Pi firmware loader
    "vc4" # display (so HDMI works during early boot)
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];
  };

  swapDevices = [ ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
