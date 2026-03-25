{
  description = "DoneTick Core - A modern task management system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    donetick-src = {
      url = "github:donetick/donetick";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      donetick-src,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.donetick = pkgs.buildGoModule {
          pname = "donetick";
          version = "0.1.0";
          src = donetick-src;

          # Update this hash with the correct one
          # Run `nix build` and it will tell you the correct hash
          vendorHash = "sha256-M2Li0StMzvufBHiQqM2RaNQax8kN8O1Gb4mJf3sLfmE=";

          subPackages = [ "." ];

          # Link the binary to a predictable name if needed
          postInstall = ''
            if [ -f $out/bin/core ]; then
              mv $out/bin/core $out/bin/donetick
            fi
          '';

          meta = with pkgs.lib; {
            description = "DoneTick Core";
            homepage = "https://github.com/donetick/donetick";
            license = licenses.mit;
          };
        };

        defaultPackage = self.packages.${system}.donetick;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            go
            gopls
            gotools
          ];
        };
      }
    )
    // {
      overlays.default = final: prev: {
        donetick = self.packages.${final.system}.donetick;
      };

      nixosModules.donetick =
        { pkgs, ... }:
        {
          imports = [ ./nixos-module.nix ];
          nixpkgs.overlays = [ self.overlays.default ];
        };

      nixosModule = self.nixosModules.donetick;
    };
}
