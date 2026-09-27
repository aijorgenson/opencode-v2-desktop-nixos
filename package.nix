{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:

let
  sourcesJson = lib.importJSON ./sources.json;
  pname = "opencode-desktop";
  inherit (sourcesJson) version;
  src =
    sourcesJson.sources.${stdenv.hostPlatform.system}
      or (throw "opencode2-desktop: unsupported system ${stdenv.hostPlatform.system}");
  appimage = fetchurl { inherit (src) url hash; };
  appimageContents = appimageTools.extract {
    inherit pname version;
    src = appimage;
  };
in
appimageTools.wrapType2 {
  inherit pname version;
  src = appimage;

  # libsecret is the one Electron extra wrapType2's default FHS set does not
  # always include; OpenCode uses it for credential storage.
  extraPkgs = pkgs: [ pkgs.libsecret ];

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/ai.opencode.desktop.desktop \
      $out/share/applications/ai.opencode.desktop.desktop
    sed -i -E \
      -e 's|^Exec=.*|Exec=opencode-desktop %U|' \
      -e 's|^Icon=.*|Icon=ai.opencode.desktop|' \
      $out/share/applications/ai.opencode.desktop.desktop

    find ${appimageContents}/usr/share/icons/hicolor -type f -name 'ai.opencode.desktop.png' |
      while read -r icon; do
        rel=''${icon#${appimageContents}/usr/}
        install -Dm444 "$icon" "$out/$rel"
      done

    install -Dm444 \
      ${appimageContents}/usr/share/icons/hicolor/128x128/apps/ai.opencode.desktop.png \
      $out/share/pixmaps/ai.opencode.desktop.png

    # wrapType2 execs the binary and skips AppRun. The published desktop entry
    # always launches with --no-sandbox, and Electron registers opencode://
    # against CHROME_DESKTOP. Keep both on the command users actually run.
    mv $out/bin/opencode-desktop $out/bin/.opencode-desktop-bwrap
    cat > $out/bin/opencode-desktop <<EOF
    #!/bin/sh
    export CHROME_DESKTOP="\''${CHROME_DESKTOP:-ai.opencode.desktop.desktop}"
    flags="--no-sandbox"
    if [ -n "\''${NIXOS_OZONE_WL:-}" ] && [ -n "\''${WAYLAND_DISPLAY:-}" ]; then
      flags="\$flags --ozone-platform-hint=auto --enable-features=WaylandWindowDecorations --enable-wayland-ime=true"
    fi
    exec $out/bin/.opencode-desktop-bwrap \$flags "\$@"
    EOF
    chmod +x $out/bin/opencode-desktop
  '';

  meta = {
    description = "OpenCode desktop app";
    homepage = "https://opencode.ai";
    downloadPage = "https://opencode.ai/v2/docs#desktop";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "opencode-desktop";
  };
}
