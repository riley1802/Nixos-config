{ config, pkgs, ... }:
{
  # Local Netdata 2.10.3. The dashboard listens on 127.0.0.1:19999.
  # Tailscale Serve terminates TLS on that port and proxies here.
  # tailscale-serve.nix installs the route. Charts and alarm state stay
  # in /var/lib/netdata, which is not in git.
  #
  # The default package builds with ENABLE_DASHBOARD=OFF. Its web
  # directory only has the swagger files, so the browser gets
  # "File does not exist, or is not accessible:". netdataCloud is that
  # package with withCloudUi, which installs the v3 dashboard. The
  # NixOS netdata test uses this package and requests the root page.
  # Hydra does not cache it because the dashboard assets are NCUL-1.
  # The agent stays unclaimed. /v3 is the anonymous local dashboard;
  # the root page is the Cloud sign-in.
  #
  # The packaged stock netdata.conf is only a comment header. It has no
  # [cloud] enabled key, so this file does not set one. claimTokenFile
  # stays unset. Anonymous statistics stay off because
  # enableAnalyticsReporting is left at the module default, false,
  # which writes the opt-out file.
  #
  # The module merges this [web] bind address with its own web settings.
  # nvidia-smi from the stable driver's bin output is appended to PATH
  # so the go.d collector can see both cards. Docker is already on that
  # PATH, and the module already puts the netdata user in the docker group.
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/pkgs/tools/system/netdata/default.nix
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/pkgs/top-level/all-packages.nix
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/tests/netdata.nix
  # https://www.netdata.cloud/blog/important-changes-to-the-netdata-agent-dashboard/
  # https://github.com/NixOS/nixpkgs/blob/6713828a351efa628b025a1adf7f43cbf8597513/nixos/modules/services/monitoring/netdata.nix
  # https://tailscale.com/kb/1242/tailscale-serve
  services.netdata = {
    enable = true;
    package = pkgs.netdataCloud;
    config.web."bind to" = "127.0.0.1:19999";
  };

  systemd.services.netdata.path = [
    config.boot.kernelPackages.nvidiaPackages.stable
  ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    19999 # Netdata
  ];
}
