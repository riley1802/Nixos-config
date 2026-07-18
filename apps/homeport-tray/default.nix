{ lib
, rustPlatform
, pkg-config
, wrapGAppsHook3
, makeDesktopItem
, copyDesktopItems
, gtk3
, webkitgtk_4_1
, libsoup_3
, libayatana-appindicator
, openssl
, dbus
, glib
,
}:

rustPlatform.buildRustPackage {
  pname = "homeport-tray";
  version = "0.1.0";

  src = lib.cleanSourceWith {
    src = ./src-tauri;
    filter = name: type:
      let base = baseNameOf (toString name);
      in base != "target" && base != "gen";
  };

  cargoLock.lockFile = ./src-tauri/Cargo.lock;

  nativeBuildInputs = [
    pkg-config
    wrapGAppsHook3
    copyDesktopItems
  ];

  buildInputs = [
    gtk3
    webkitgtk_4_1
    libsoup_3
    libayatana-appindicator
    openssl
    dbus
    glib
  ];

  desktopItems = [
    (makeDesktopItem {
      name = "homeport-tray";
      exec = "homeport-tray";
      desktopName = "Homeport";
      comment = "Homeport dashboard, tray icon, and alert notifications";
      icon = "homeport-tray";
      categories = [ "Network" "Monitor" ];
      startupNotify = true;
    })
  ];

  postInstall = ''
    install -Dm644 icons/tray-normal.png \
      $out/share/icons/hicolor/128x128/apps/homeport-tray.png
  '';

  # libayatana-appindicator is dlopen()'d at runtime (not linked), so
  # wrapGAppsHook's usual wrapper doesn't put it on the search path — add it
  # to LD_LIBRARY_PATH explicitly or the tray icon fails to initialize.
  preFixup = ''
    gappsWrapperArgs+=(--prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}")
  '';

  meta = with lib; {
    description = "Tray companion window for the Homeport dashboard, with native ntfy alert notifications";
    mainProgram = "homeport-tray";
    platforms = platforms.linux;
  };
}
