{
  lib,
  pkgs,
  nixcordPkgs ? { },
  ...
}:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.programs.nixcord.discord = {
    enable = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Whether to enable discord
        Disable to only install Vesktop
      '';
    };
    installPackage = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add `cfg.finalPackage.discord` to `home.packages`.";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../pkgs/discord.nix (
        lib.optionalAttrs (
          pkgs.stdenvNoCC.isLinux && builtins.fromJSON (lib.versions.major lib.version) < 25
        ) { libgbm = pkgs.mesa; }
      );
      description = ''
        The Discord package to use
      '';
    };
    branch = mkOption {
      type = types.enum [
        "stable"
        "ptb"
        "canary"
        "development"
      ];
      default = "stable";
      description = "The Discord branch to use";
    };
    configDir = mkOption {
      type = types.path;
      description = "Config path for Discord";
    };
    vencord = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Enable Vencord (for non-vesktop)";
      };
      package = mkOption {
        type = types.package;
        default = nixcordPkgs.vencord or (pkgs.callPackage ../../pkgs/vencord.nix { unstable = false; });
        defaultText = lib.literalExpression "pkgs.callPackage ../../pkgs/vencord.nix { unstable = false; }";
        description = ''
          The Vencord package to use
        '';
      };
      unstable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable unstable Vencord build from repository's master branch";
      };
    };
    equicord = {
      enable = mkEnableOption "Equicord (alternative to Vencord)";
      package = mkOption {
        type = types.package;
        default = nixcordPkgs.equicord or (pkgs.callPackage ../../pkgs/equicord.nix { });
        description = ''
          The Equicord package to use
        '';
      };
    };
    openASAR.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Enable OpenASAR (for non-vesktop)";
    };
    autoscroll.enable = mkEnableOption "middle-click autoscrolling";
    settings = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Settings to be placed in discordConfigDir/settings.json
      '';
    };
  };
}
