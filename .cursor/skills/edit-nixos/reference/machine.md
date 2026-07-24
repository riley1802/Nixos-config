# Machines

## nixos (desktop)

- Hostname: `nixos`
- User: `rileyt`
- Desktop: Cinnamon + LightDM (X11, shared `modules/desktop/cinnamon.nix`)
- GPUs: RTX 3050 + GTX 1660 Super
- Repo path: `/etc/nixos`
- Remote: `git@github.com:riley1802/Nixos-config.git`

## legion (laptop)

- Hostname: `legion` — Lenovo Legion 5 Pro 16ARH7H
- User: `rileyt`
- Desktop: Cinnamon + LightDM (X11, shared `modules/desktop/cinnamon.nix`)
- GPUs: AMD Radeon 680M iGPU (PCI 35:00.0) + RTX 3070 Ti dGPU (PCI 01:00.0), PRIME offload (`modules/hardware/nvidia-prime.nix`)
- **BIOS "GPU Working Mode" must be Hybrid.** Discrete mode muxes the panel to the NVIDIA card, leaving the iGPU with no outputs → black screen under the X11 offload config.

## Publishing caution

`hardware-configuration.nix` and `modules/users/rileyt.nix` contain machine-specific data. Review before public push.
