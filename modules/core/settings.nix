# Shared values any module can read, such as config.my.user.
{ lib, ... }:
{
  options.my.user = lib.mkOption {
    type = lib.types.str;
    description = "Main login user of this computer.";
  };

  options.my.tailnetHost = lib.mkOption {
    type = lib.types.str;
    description = "This computer's MagicDNS name.";
  };

  options.my.lanInterface = lib.mkOption {
    type = lib.types.str;
    description = "Home-network interface. Services that are open on the LAN name this.";
  };
}
