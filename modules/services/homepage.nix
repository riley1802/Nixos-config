{ ... }:

{
  services.homepage-dashboard = {
    enable = true;
    openFirewall = false;

    settings = {
      title = "Homelab";
      headerStyle = "boxed";
      theme = "dark";
      color = "slate";
    };

    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          disk = "/";
        };
      }
      {
        search = {
          provider = "google";
          target = "_blank";
        };
      }
    ];

    services = [
      {
        Homelab = [
          {
            Homepage = {
              href = "http://127.0.0.1:8082";
              description = "This dashboard";
            };
          }
          {
            "Uptime Kuma" = {
              href = "http://127.0.0.1:3001";
              description = "Service monitoring";
            };
          }
          {
            "Desktop (nixos)" = {
              href = "http://nixos";
              description = "Main workstation over Tailscale";
            };
          }
        ];
      }
    ];
  };
}
