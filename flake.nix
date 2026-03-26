{
  description = "DoneTick Core - A modern task management system";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    donetick-src = {
      url = "github:donetick/donetick";
      flake = false;
    };
    donetick-frontend = {
      url = "git+ssh://git@github.com/donetick/frontend.git";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      donetick-src,
      donetick-frontend,
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

        packages.donetick-frontend = pkgs.buildNpmPackage {
          pname = "donetick-frontend";
          version = "0.1.0";
          src = donetick-frontend;

          # Update this hash with the correct one
          # Run `nix build .#donetick-frontend` and it will tell you the correct hash
          npmDepsHash = "sha256-0000000000000000000000000000000000000000000=";

          # Use Node.js 20 explicitly
          nodejs = pkgs.nodejs_20;

          npmDepsFetcherVersion = 2;
          makeCacheWritable = true;

          # Flags for both fetcher and installer
          npmFlags = [
            "--legacy-peer-deps"
            "--ignore-scripts"
          ];
          npmDepsFlags = [
            "--legacy-peer-deps"
            "--ignore-scripts"
          ];

          installPhase = ''
            mkdir -p $out/share/donetick-frontend
            cp -r dist/* $out/share/donetick-frontend/
          '';

          meta = with pkgs.lib; {
            description = "DoneTick Frontend";
            homepage = "https://github.com/donetick/frontend";
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
        donetick-frontend = self.packages.${final.system}.donetick-frontend;
      };

      nixosModules.donetick = {
        imports = [ ./nixos-module.nix ];
        nixpkgs.overlays = [ self.overlays.default ];
      };

      nixosModule = self.nixosModules.donetick;
    };
}
