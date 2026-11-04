# Chrome policy so tailnet names use the system DNS resolver.
{ config, lib, ... }:
let
  cfg = config.my.desktop.chrome;
in
{
  options.my.desktop.chrome.enable = lib.mkEnableOption "Chrome DNS policy";

  config = lib.mkIf cfg.enable {
    # Chrome was set to "secure" DNS through Cloudflare only. That never
    # asks the local forwarder, so tailnet names do not resolve and Chrome
    # reports that the site cannot be reached. Off means Chrome uses the
    # system resolver above.
    # https://chromeenterprise.google/policies/#DnsOverHttpsMode
    environment.etc."opt/chrome/policies/managed/dns.json".text = builtins.toJSON {
      DnsOverHttpsMode = "off";
    };
  };
}
