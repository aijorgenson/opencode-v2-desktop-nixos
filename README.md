# opencode2-desktop

> [OpenCode Desktop](https://opencode.ai/v2/docs#desktop) on NixOS, wrapping the
> official Linux AppImage. A GitHub Action bumps the pin when a new stable
> build ships.

OpenCode publishes Linux AppImage, `.deb`, and `.rpm` builds. This flake
takes the AppImage and wraps it in an FHS environment. The current pin is in
`sources.json`.

- [Try it without installing](#try-it-without-installing)
- [Add it to your flake](#add-it-to-your-flake)
- [Updating](#updating)
- [License](#license)

## Try it without installing

```sh
nix run github:aijorgenson/opencode2-desktop
```

`nix run` does not install the desktop file, so `opencode://` links will not
route back to the app until it is installed (the module below, Home Manager,
or `nix profile install`).

## Add it to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    opencode-desktop = {
      url = "github:aijorgenson/opencode2-desktop";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, opencode-desktop, ... }: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
        opencode-desktop.nixosModules.default
      ];
    };
  };
}
```

### Or just the package

```nix
{ pkgs, opencode-desktop, ... }:
{
  environment.systemPackages = [ opencode-desktop.packages.${pkgs.system}.default ];
}
```

(Pass `opencode-desktop` through `specialArgs` if the module file is not the flake's
`outputs`.)

Linux only: `x86_64-linux` and `aarch64-linux`.

On Wayland, set `environment.sessionVariables.NIXOS_OZONE_WL = "1";` and the
wrapper adds the usual Ozone flags.

## Updating

`sources.json` pins the AppImage URL and hash for each Linux arch. A
scheduled Action queries the stable desktop update API once a day, and when
the version moved, runs `./update-package.sh`, builds, and pushes straight to
`main`.

The API is `https://opencode.ai/update/api/latest/desktop/opencode/`. The
AppImage URLs are `opencode-desktop-linux-x86_64.AppImage` and
`opencode-desktop-linux-arm64.AppImage`.

Requirements for the Action:

- **Settings → Actions → General → Workflow permissions** = "Read and write
  permissions"
- If `main` is protected, allow `github-actions[bot]` to push

Trigger it by hand from the Actions tab ("Run workflow").

### Manual

```sh
./update-package.sh
```

It fetches the latest stable metadata, refuses to update unless both Linux
AppImages are published for that version, prefetches hashes, writes
`sources.json`, and `nix build`s. Nothing is committed.

## License

The Nix expressions and scripts in this repo are [MIT](LICENSE). That covers
the packaging only.

OpenCode itself is also MIT. This flake does not ship the AppImage; Nix
downloads it at build time. The AppImage bundles Electron and Chromium under
their own licenses. This project is unofficial and not affiliated with
Anomaly.

---

> Built and tested on `x86_64-linux`.
