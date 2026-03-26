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
      url = "github:donetick/frontend";
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

        donetick-frontend-built = pkgs.buildNpmPackage {
          pname = "donetick-frontend";
          version = "1.2.0";
          src = donetick-frontend;

          npmDepsHash = "sha256-oGvO3lcc02MtYZUWz9XgGslHnxvBViReDTOdQZArR24=";
          npmDepsFetcherVersion = 2;

          # Use build script from package.json but pass flags
          npmBuildScript = "build";
          npmBuildFlags = [
            "--"
            "--mode"
            "selfhosted"
          ];

          # Avoid peer dependency issues often found in modern npm
          npmFlags = [ "--legacy-peer-deps" ];

          # Necessary for some node_modules that try to write to their own directory
          makeCacheWritable = true;

          installPhase = ''
            mkdir -p $out
            cp -r dist/* $out/
          '';
        };

        donetick-with-frontend = pkgs.runCommand "donetick-src-with-frontend" { } ''
          mkdir -p $out/frontend/dist
          cp -r ${donetick-src}/* $out/
          chmod -R u+w $out
          cp -r ${donetick-frontend-built}/* $out/frontend/dist/
        '';
      in
      {
        packages.donetick = pkgs.buildGoModule {
          pname = "donetick";
          version = "0.1.0";
          src = donetick-with-frontend;

          vendorHash = "sha256-M2Li0StMzvufBHiQqM2RaNQax8kN8O1Gb4mJf3sLfmE=";

          subPackages = [ "." ];

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
            nodejs
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
