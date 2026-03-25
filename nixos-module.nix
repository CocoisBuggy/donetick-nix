{
  config,
  pkgs,
  lib,
  ...
}:

let
  cfg = config.services.donetick;
in
{
  options.services.donetick = {
    enable = lib.mkEnableOption "DoneTick Core";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.donetick;
      description = "The package to use for DoneTick Core.";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "donetick";
      description = "The user to run DoneTick Core as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "donetick";
      description = "The group to run DoneTick Core as.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/donetick";
      description = "The directory to store DoneTick Core data (e.g., SQLite DB).";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2021;
      description = "The port to listen on.";
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        DT_JWT_SECRET = "something-very-secure-at-least-32-chars-long";
      };
      description = "Environment variables for DoneTick Core.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = { };
      description = "Configuration settings for DoneTick Core (serialized to YAML).";
    };

    configEnv = lib.mkOption {
      type = lib.types.enum [
        "local"
        "prod"
        "selfhosted"
      ];
      default = "selfhosted";
      description = "The environment type for configuration loading.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.donetick = {
      description = "DoneTick Core Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      preStart =
        let
          dbPath = "${cfg.dataDir}/donetick.db";
          yamlConfig = lib.generators.toYAML { } (
            {
              database = {
                type = "sqlite";
                path = dbPath;
              };
            }
            // cfg.settings
          );
        in
        ''
          mkdir -p config
          ln -sf "${pkgs.writeText "${cfg.configEnv}.yaml" yamlConfig}" config/${cfg.configEnv}.yaml
        '';

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/donetick";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        Restart = "always";

        Environment = [
          "DT_ENV=${cfg.configEnv}"
          "DT_SERVER_PORT=${toString cfg.port}"
          "DT_SQLITE_PATH=${cfg.dataDir}/donetick.db"
          "TZ=UTC"
        ]
        ++ (lib.mapAttrsToList (n: v: "${n}=${v}") cfg.environment);

        # Hardening
        StateDirectory = "donetick";
        CapabilityBoundingSet = "";
        NoNewPrivileges = true;
        ProtectSystem = "full";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
          "AF_UNIX"
        ];
      };
    };

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = false; # Handled by StateDirectory
    };

    users.groups.${cfg.group} = { };
  };
}
