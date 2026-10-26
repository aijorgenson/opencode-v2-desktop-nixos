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
    desktopFile=${appimageContents}/ai.opencode.desktop.desktop
    install -Dm444 "$desktopFile" \
      $out/share/applications/ai.opencode.desktop.desktop

    # Follow the icon name the upstream desktop entry actually declares instead
    # of hardcoding a filename: 2.1.x renamed ai.opencode.desktop.png to
    # ai.opencode.png, and upstream may rename it again.
    iconName="$(sed -n 's|^Icon=||p' "$desktopFile" | head -n 1)"
    if [ -z "$iconName" ]; then
      echo "opencode-desktop: no Icon= entry in $desktopFile" >&2
      exit 1
    fi

    sed -i -E \
      -e 's|^Exec=.*|Exec=opencode-desktop %U|' \
      -e "s|^Icon=.*|Icon=$iconName|" \
      $out/share/applications/ai.opencode.desktop.desktop

    largestIcon="$(find ${appimageContents}/usr/share/icons/hicolor \
      -path '*/apps/*' -type f -name "$iconName.png" |
      sort -V | tail -n 1)"
    if [ -z "$largestIcon" ]; then
      echo "opencode-desktop: no $iconName.png icons in the AppImage" >&2
      exit 1
    fi

    find ${appimageContents}/usr/share/icons/hicolor \
      -path '*/apps/*' -type f -name "$iconName.png" |
      while read -r icon; do
        rel=''${icon#${appimageContents}/usr/}
        install -Dm444 "$icon" "$out/$rel"
      done

    install -Dm444 "$largestIcon" "$out/share/pixmaps/$iconName.png"

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
