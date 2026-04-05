{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.programs.nixcord.equibop = {
    enable = mkEnableOption "Equibop";
    installPackage = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the final Equibop package.";
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
      description = "The Equibop package to use.";
    };
    useSystemEquicord = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to use the system Equicord package instead of the bundled one.";
    };
    configDir = mkOption {
      type = types.path;
      description = "Config directory for Equibop.";
    };
    settings = mkOption {
      type = types.attrs;
      default = { };
      description = "Settings to be placed in Equibop's settings.json.";
    };
    state = mkOption {
      type = types.attrs;
      default = { };
      description = "State to be placed in Equibop's state.json.";
    };
    autoscroll.enable = mkEnableOption "middle-click autoscrolling for Equibop";
  };
}
