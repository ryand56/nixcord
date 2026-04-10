{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.programs.nixcord.legcord = {
    enable = mkEnableOption "Legcord";
    installPackage = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the Legcord package.";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.legcord;
      defaultText = lib.literalExpression "pkgs.legcord";
      description = "The Legcord package to use.";
    };
    configDir = mkOption {
      type = types.path;
      description = "Config directory for Legcord.";
    };
    vencord = {
      enable = mkEnableOption "bundling Vencord for Legcord (includes userPlugins)";
    };
    equicord = {
      enable = mkEnableOption "bundling Equicord for Legcord (includes userPlugins)";
    };
    settings = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Settings to be written to Legcord's storage/settings.json.";
      example = {
        channel = "stable";
        tray = "dynamic";
        minimizeToTray = true;
        hardwareAcceleration = true;
        mods = [ "vencord" ];
        doneSetup = true;
      };
    };
  };
}
