{ lib
, buildFHSEnv
, fetchzip
, icu
, openssl
, stdenv
, writeShellScript
, zlib
,
}:

# nixpkgs does not package Cleanuparr. This is the official 2.10.12
# linux-amd64 build. It is a self-contained .NET single file, so changing
# its loader with patchelf shifts the bundle and the program will not start.
# The FHS env gives it the usual /lib64 loader instead. wwwroot and
# libe_sqlite3.so have to stay beside the binary, which they do in this zip.
# https://github.com/Cleanuparr/Cleanuparr/releases/tag/v2.10.12
# https://github.com/Cleanuparr/Cleanuparr/blob/v2.10.12/docs/docs/installation/detailed.mdx
let
  version = "2.10.12";
  unpacked = fetchzip {
    url = "https://github.com/Cleanuparr/Cleanuparr/releases/download/v${version}/Cleanuparr-${version}-linux-amd64.zip";
    hash = "sha256-XOb4CNsqxTlceZiDRfClwxVaKo+7aZFdSxhUunix8/8=";
    stripRoot = true;
  };
in
buildFHSEnv {
  name = "cleanuparr";

  targetPkgs = _pkgs: [
    icu
    openssl
    stdenv.cc.cc.lib
    zlib
  ];

  # ASP.NET uses the working directory as the content root. The UI is
  # wwwroot next to the binary, and that store path is read-only. The
  # database stays in CLEANUPARR_CONFIG_PATH.
  runScript = writeShellScript "cleanuparr-start" ''
    cd ${unpacked}
    exec ${unpacked}/Cleanuparr "$@"
  '';

  meta = {
    description = "Download cleanup for Sonarr, Radarr, Lidarr, and qBittorrent";
    homepage = "https://github.com/Cleanuparr/Cleanuparr";
    license = lib.licenses.gpl3Only;
    mainProgram = "cleanuparr";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
