{
  description = "OpenCode Desktop for NixOS, wrapping the official Linux AppImage";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAll =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
            }
          )
        );
    in
    {
      packages = forAll (pkgs: rec {
        opencode-desktop = pkgs.callPackage ./package.nix { };
        default = opencode-desktop;
      });

      overlays.default = final: prev: {
        opencode-desktop = final.callPackage ./package.nix { };
      };

      nixosModules.default =
        { pkgs, ... }:
        {
          nixpkgs.overlays = [ self.overlays.default ];
          environment.systemPackages = [ pkgs.opencode-desktop ];
        };
    };
}
