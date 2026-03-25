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

        donetick-with-frontend =
          pkgs.runCommand "donetick-src-with-frontend"
            {
              nativeBuildInputs = [
                pkgs.nodejs
                pkgs.pnpm
              ];
              allowSubstitutes = false;
              preferLocalBuild = true;
              allowNetwork = true;
            }
            ''
              set -e
              mkdir -p $out
              WORKDIR=$(mktemp -d)
              chmod -R 755 "$WORKDIR"
              export HOME="$WORKDIR"
              export TMPDIR="$WORKDIR"
              export PNPM_HOME="$WORKDIR/.pnpm"
              export NODE_EXTRA_CA_CERTS="${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              cp -r ${donetick-src} "$WORKDIR/src"
              cp -r ${donetick-frontend} "$WORKDIR/frontend-src"
              chmod -R u+w "$WORKDIR"
              cd "$WORKDIR/frontend-src"
              pnpm config set shamefully-hoist true
              pnpm install
              pnpm exec vite build --mode selfhosted
              mkdir -p "$WORKDIR/src/frontend"
              mv "$WORKDIR/frontend-src/dist"/* "$WORKDIR/src/frontend/" || mv "$WORKDIR/frontend-src/dist" "$WORKDIR/src/frontend"
              rm -rf "$WORKDIR/frontend-src"
              cp -r "$WORKDIR/src/"* $out/
              rm -rf "$WORKDIR"
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
