{ ... }:

# Everything shared by all hosts: core system, programs, users, and the full
# service stack. Hosts add only hardware and desktop-environment modules.
{
  imports = [
    ../modules/core/boot.nix
    ../modules/core/locale.nix
    ../modules/core/hostname.nix
    ../modules/core/host-facts.nix
    ../modules/core/networkmanager.nix
    ../modules/core/openssh.nix
    ../modules/core/agenix.nix
    ../modules/core/nix.nix
    ../modules/core/nixpkgs.nix
    ../modules/core/state-version.nix
    ../modules/core/polkit-pkexec.nix

    ../modules/hardware/graphics.nix

    ../modules/desktop/audio.nix

    ../modules/programs/firefox.nix
    ../modules/programs/steam.nix
    ../modules/programs/games-dirs.nix
    ../modules/programs/packages.nix

    ../modules/services/llama-cpp.nix
    ../modules/services/whisper-cpp.nix
    ../modules/services/piper.nix
    ../modules/services/printing.nix
    ../modules/services/searxng.nix
    ../modules/services/tailscale.nix
    ../modules/services/postgresql.nix
    ../modules/services/n8n.nix
    ../modules/services/docker.nix
    ../modules/services/uptime-kuma.nix
    ../modules/services/homepage-dashboard.nix
    ../modules/services/gpu-stats.nix
    ../modules/services/ntfy-sh.nix
    ../modules/services/tailscale-serve.nix
    # ../modules/services/honcho.nix # Honcho server stack — uncomment when ready

    ../modules/users/rileyt.nix
  ];
}
