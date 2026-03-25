# DoneTick Nix

Nix flake and NixOS module for [DoneTick](https://github.com/donetick/donetick).

## Features

- **Nix Flake**: Easily integrate DoneTick into your Nix-based workflow.
- **NixOS Module**: Simple service configuration for NixOS.
- **Hardened Service**: Runs with a dedicated system user and various systemd hardening flags.
- **SQLite by Default**: Zero-config database setup, but supports PostgreSQL if needed.

## Usage

### 1. Add to your Flake

Add this repository to your `flake.nix` inputs:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    donetick.url = "github:CocoisBuggy/donetick-nix";
  };

  outputs = { self, nixpkgs, donetick, ... }: {
    nixosConfigurations.your-hostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        donetick.nixosModules.donetick
        ./configuration.nix
      ];
    };
  };
}
```

### 2. Enable the Service

Add the following to your `configuration.nix`:

```nix
{
  services.donetick = {
    enable = true;
    environment = {
      # A secure 32+ character secret is REQUIRED for the application to start.
      # You can generate one with: openssl rand -base64 32
      DT_JWT_SECRET = "your-secure-secret-here-at-least-32-chars";
    };
  };
}
```

## Configuration Reference

The NixOS module provides the following options:

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `services.donetick.enable` | boolean | `false` | Whether to enable DoneTick Core. |
| `services.donetick.port` | port | `2021` | The port the server will listen on. |
| `services.donetick.dataDir` | string | `"/var/lib/donetick"` | Directory for persistent data (SQLite DB). |
| `services.donetick.configEnv` | enum | `"selfhosted"` | Environment type (`local`, `prod`, `selfhosted`). |
| `services.donetick.environment` | attrs | `{}` | Environment variables (e.g., `DT_JWT_SECRET`). |
| `services.donetick.settings` | attrs | `{}` | Structured configuration serialized to YAML. |

### Example with custom settings:

```nix
services.donetick = {
  enable = true;
  port = 8080;
  settings = {
    log = {
      level = "debug";
    };
  };
};
```

## Building Manually

You can build the package directly using:

```bash
nix build github:donetick/donetick-nix#donetick
```

Or run it immediately:

```bash
nix run github:donetick/donetick-nix#donetick
```

## License

MIT
