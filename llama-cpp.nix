{ pkgs, ... }:

{
  environment.systemPackages = [
    (pkgs.llama-cpp.override { cudaSupport = true; })
  ];

  systemd.tmpfiles.rules = [
    "d /home/rileyt/.local/share/llama.cpp 0755 rileyt users - -"
    "d /home/rileyt/.local/share/llama.cpp/models 0755 rileyt users - -"
  ];
}
