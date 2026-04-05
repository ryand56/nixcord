{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.programs.nixcord.equibop = {
    enable = mkEnableOption ''
      Whether to enable Equibop
    '';
    installPackage = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add `cfg.finalPackage.equibop` to `home.packages`.";
    };
    package = mkOption {
      type = types.nullOr types.package;
      default =
        if pkgs.stdenvNoCC.isDarwin then
          null
        else if pkgs ? equibop then
          pkgs.equibop
        else
          null;
      description = ''
        The Equibop package to use
      '';
    };
    useSystemEquicord = mkOption {
      type = types.bool;
      default = true;
      description = "Use system Equicord package instead of the bundled one";
    };
    configDir = mkOption {
      type = types.path;
      description = "Config path for Equibop";
    };
    settings = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Settings to be placed in equibop.configDir/settings.json
      '';
    };
    state = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Settings to be placed in equibop.configDir/state.json
      '';
    };
    autoscroll.enable = mkEnableOption "middle-click autoscrolling";
  };
}
