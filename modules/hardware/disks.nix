# Extra disks: the vault SSD and the USB game drive.
{ config, lib, ... }:
let
  cfg = config.my.hardware.disks;
in
{
  options.my.hardware.disks.enable = lib.mkEnableOption "vault disk and game drive";

  config = lib.mkIf cfg.enable {
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

    systemd.services.systemd-tmpfiles-setup.after = [ "vault.mount" ];
    systemd.services.systemd-tmpfiles-resetup.after = [ "vault.mount" ];
  };
}
