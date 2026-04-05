# Computes all shared intermediate values needed by every platform module.
# Returns an attrset of { cfg, mkVencordCfg, mkFinalPackages,
#   vencordFullConfig, equicordFullConfig, vesktopFullConfig, equibopFullConfig,
#   vencord, equicord, isQuickCssUsed, mkDorionConfigAttrs, mkConfigDirs,
#   settingsFiles, vesktopThemes, dorionConfigFile, quickCssFile }.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.nixcord;

  inherit (import ./shared.nix { inherit lib; })
    applyPostPatch
    mkIsQuickCssUsed
    mkPluginKit
    mkDorionConfigAttrs
    mkSettingsFiles
    mkThemeFile
    mkConfigDirs
    mkAllFullConfigs
    ;

  parseRules = cfg.parseRules;

  inherit (pkgs.callPackage ./core.nix { inherit lib parseRules; }) mkVencordCfg mkFinalPackages;

  pluginKit = mkPluginKit { inherit cfg; };

  inherit (mkAllFullConfigs { inherit cfg pluginKit; })
    vencordFullConfig
    equicordFullConfig
    vesktopFullConfig
    equibopFullConfig
    ;

  vencord = applyPostPatch {
    inherit cfg;
    pkg = cfg.discord.vencord.package;
  };

  equicord = applyPostPatch {
    inherit cfg;
    pkg = cfg.discord.equicord.package;
  };

  isQuickCssUsed = mkIsQuickCssUsed { inherit cfg; };

  quickCssFile = pkgs.writeText "nixcord-quickcss.css" cfg.quickCss;

  settingsFiles = mkSettingsFiles {
    inherit
      pkgs
      cfg
      mkVencordCfg
      vencordFullConfig
      equicordFullConfig
      vesktopFullConfig
      equibopFullConfig
      ;
  };

  vesktopThemes = lib.mapAttrs (mkThemeFile { inherit pkgs; }) cfg.config.themes;

  dorionConfigFile =
    if cfg.dorion.enable then
      pkgs.writeText "nixcord-dorion-config.json" (
        builtins.toJSON (mkDorionConfigAttrs {
          inherit cfg;
        })
      )
    else
      null;
in
{
  inherit
    cfg
    mkVencordCfg
    mkFinalPackages
    vencordFullConfig
    equicordFullConfig
    vesktopFullConfig
    equibopFullConfig
    vencord
    equicord
    isQuickCssUsed
    mkDorionConfigAttrs
    mkConfigDirs
    settingsFiles
    vesktopThemes
    dorionConfigFile
    quickCssFile
    ;
}
