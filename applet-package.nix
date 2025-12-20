{ lib
, rustPlatform
, pkg-config
, libxkbcommon
, wayland
, libinput
, udev
, mesa
, fontconfig
, freetype
, expat
, nerd-dictation
, libcosmicAppHook
}:

rustPlatform.buildRustPackage rec {
  pname = "cosmic-applet-nerd-dictation";
  version = "0.1.0";

  src = ./cosmic-applet;

  cargoHash = "sha256-0ERe94boYSHsUNTufYjkH9+V8gRygclCPion4v/MRSw=";

  nativeBuildInputs = [
    libcosmicAppHook
    pkg-config
  ];

  buildInputs = [
    libxkbcommon
    wayland
    libinput
    udev
    mesa
    fontconfig
    freetype
    expat
  ];

  # Ensure nerd-dictation is available at runtime
  propagatedBuildInputs = [ nerd-dictation ];

  postInstall = ''
    # Install desktop file
    install -Dm644 data/com.digunix.CosmicAppletNerdDictation.desktop \
      $out/share/applications/com.digunix.CosmicAppletNerdDictation.desktop

    # Install icons
    for icon in resources/icons/*.svg; do
      install -Dm644 "$icon" \
        $out/share/icons/hicolor/scalable/apps/$(basename "$icon")
    done
  '';

  meta = with lib; {
    description = "COSMIC panel applet for nerd-dictation status and control";
    homepage = "https://github.com/digunix/nix-nerd-dictation";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    mainProgram = "cosmic-applet-nerd-dictation";
  };
}
