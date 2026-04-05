{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  imports = [
    ./discord.nix
    ./vesktop.nix
    ./equibop.nix
    ./dorion.nix
    ./vencord-config.nix
    ./legacy.nix
    ./extra.nix
  ];

  options.programs.nixcord = {
    user = mkOption {
      type = types.str;
      description = "Target username";
    };

    homeDirectory = mkOption {
      type = types.path;
      description = "Home directory for the target user";
    };

    xdgConfigHome = mkOption {
      type = types.path;
      description = "XDG config home directory";
    };

    enable = mkEnableOption "Enables Discord with Vencord";

    configDir = mkOption {
      type = types.path;
      description = "Config directory for the selected client (Vencord or Equicord)";
    };

    finalPackage = {
      discord = mkOption {
        type = types.package;
        readOnly = true;
        description = "The final discord package that is created";
      };

      vesktop = mkOption {
        type = types.package;
        readOnly = true;
        description = "The final vesktop package that is created";
      };
      equibop = mkOption {
        type = types.nullOr types.package;
        readOnly = true;
        description = "The final equibop package that is created (null if package is not provided)";
      };

      dorion = mkOption {
        type = types.package;
        readOnly = true;
        description = "The final dorion package that is created";
      };
    };
  };
}
