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

  # The 1660 SUPER has 6 GB. Breeze TTS and Nemotron do not fit together.
  # Both units stay installed. This value is the one systemd starts at boot,
  # and the one Tailscale, Open WebUI, and Homarr publish.
  options.my.hardware.gtx1660 = lib.mkOption {
    type = lib.types.enum [
      "breeze-tts"
      "nemotron"
    ];
    default = "breeze-tts";
    description = "Which service owns the GTX 1660 SUPER.";
  };
}
