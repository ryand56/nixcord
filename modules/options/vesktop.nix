{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.programs.nixcord.vesktop = {
    enable = mkEnableOption ''
      Whether to enable Vesktop
    '';
    installPackage = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add `cfg.finalPackage.vesktop` to `home.packages`.";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.vesktop;
      description = ''
        The Vesktop package to use
      '';
    };
    useSystemVencord = mkOption {
      type = types.bool;
      default = true;
      description = "Use system Vencord package";
    };
    configDir = mkOption {
      type = types.path;
      description = "Config path for Vesktop";
    };
    settings = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Settings to be placed in vesktop.configDir/settings.json
      '';
    };
    state = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Settings to be placed in vesktop.configDir/state.json
      '';
    };
    autoscroll.enable = mkEnableOption "middle-click autoscrolling";
  };
}
