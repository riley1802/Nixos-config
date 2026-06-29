{
  lib,
  stdenv,
  fetchurl,
  binutils,
  zstd,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  atk,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  cairo,
  cups,
  dbus,
  expat,
  gdk-pixbuf,
  glib,
  gtk3,
  libdrm,
  libxkbcommon,
  libx11,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxrandr,
  libxcb,
  libglvnd,
  mesa,
  nspr,
  nss,
  pango,
  udev,
}:

stdenv.mkDerivation rec {
  pname = "goose-desktop";
  version = "1.39.0";

  src = fetchurl {
    url = "https://github.com/aaif-goose/goose/releases/download/v${version}/goose_${version}_amd64.deb";
    hash = "sha256-nn7G4+84m55k8KXGHVnBUsfD8wuI4ZnAmjhVHM6Y8j4=";
  };

  nativeBuildInputs = [
    binutils
    zstd
    autoPatchelfHook
    makeWrapper
    wrapGAppsHook3
  ];

  buildInputs = [
    alsa-lib
    atk
    at-spi2-atk
    at-spi2-core
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libdrm
    libxkbcommon
    mesa
    nspr
    nss
    pango
    udev
    libx11
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxrandr
    libxcb
    libglvnd
  ];

  sourceRoot = "source";

  unpackPhase = ''
    runHook preUnpack
    mkdir source
    ${binutils}/bin/ar x "$src"
    tar --no-same-owner --no-same-permissions --zstd -xf data.tar.zst -C source
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/goose" "$out/bin" "$out/share/applications" "$out/share/pixmaps"
    cp -r usr/lib/goose/* "$out/lib/goose/"
    cp usr/share/pixmaps/goose.png "$out/share/pixmaps/"

    makeWrapper "$out/lib/goose/Goose" "$out/bin/goose-desktop" \
      --add-flags "--disable-gpu-sandbox --no-sandbox --disable-dev-shm-usage" \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath buildInputs}:$out/lib/goose"

    substituteInPlace usr/share/applications/goose.desktop \
      --replace-fail "/usr/lib/goose/Goose" "goose-desktop" \
      --replace-fail "/usr/share/pixmaps/goose.png" "goose"

    cp usr/share/applications/goose.desktop "$out/share/applications/"

    runHook postInstall
  '';

  meta = {
    description = "Goose desktop AI agent";
    homepage = "https://goose-docs.ai/";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "goose-desktop";
  };
}
