# Google Antigravity CLI (agy).
# shortcut: version/url/hash pinned to manifest, bump when build hash fails — https://antigravity-cli-auto-updater-974169037036.us-central1.run.app/manifests/linux_amd64.json
{ lib, stdenv, fetchurl, patchelf }:

stdenv.mkDerivation (finalAttrs: {
  pname = "agy";
  version = "1.5.9";

  src = fetchurl {
    url = "https://storage.googleapis.com/antigravity-public/antigravity-cli/1.5.9-4515810895593472/linux-x64/cli_linux_x64.tar.gz";
    hash = "sha512-0B6xO6d1Du0YkH8a6IYIZDceCtkGRBXo0DPSK0vXubTkx/liBYUgtFLWfbHDMWPZqInVWn3/oVlZbsbNkah7eQ==";
  };

  nativeBuildInputs = [ patchelf ];

  dontStrip = true;
  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    tar -xOf $src antigravity > $out/bin/agy
    chmod +x $out/bin/agy
    patchelf --set-interpreter "${stdenv.cc.bintools.dynamicLinker}" $out/bin/agy
    runHook postInstall
  '';

  meta = {
    description = "Google Antigravity CLI";
    homepage = "https://antigravity.google";
    license = lib.licenses.unfree;
    mainProgram = "agy";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
})
