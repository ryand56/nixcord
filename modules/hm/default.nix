{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    ;

  inherit (pkgs.callPackage ../lib/shared.nix { inherit lib; })
    applyPostPatch
    mkIsQuickCssUsed
    mkPluginKit
    mkDorionConfigAttrs
    mkConfigDirs
    mkAllFullConfigs
    ;

in
{
  imports = [
    ../options
    ../plugins/migrations.nix
    ../warnings.nix
  ];

  config = mkIf config.programs.nixcord.enable (
    let
      cfg = config.programs.nixcord;

      parseRules = cfg.parseRules;

      inherit (pkgs.callPackage ../lib/core.nix { inherit lib parseRules; })
        mkVencordCfg
        mkFinalPackages
        ;

      pluginKit = mkPluginKit { inherit cfg; };

      inherit (mkAllFullConfigs { inherit cfg pluginKit; })
        vencordFullConfig
        equicordFullConfig
        vesktopFullConfig
        equibopFullConfig
        ;

      activationScripts = import ../lib/activation.nix {
        inherit
          lib
          pkgs
          cfg
          mkVencordCfg
          ;
        wrapScript = script: lib.hm.dag.entryAfter [ "writeBoundary" ] script;
      };

      vencord = applyPostPatch {
        inherit cfg;
        pkg = cfg.discord.vencord.package;
      };
      equicord = applyPostPatch {
        inherit cfg;
        pkg = cfg.discord.equicord.package;
      };

      isQuickCssUsed = mkIsQuickCssUsed { inherit cfg; };

    in
    mkMerge ([
      {
        programs.nixcord = {
          user = lib.mkDefault config.home.username;
        }
        // mkConfigDirs {
          inherit cfg;
          basePath =
            if pkgs.stdenvNoCC.isLinux then
              config.xdg.configHome
            else
              "${config.home.homeDirectory}/Library/Application Support";
        };
      }
      {
        programs.nixcord.finalPackage = mkFinalPackages {
          inherit cfg;
          inherit vencord equicord;
        };

        home.packages = mkMerge [
          (mkIf (cfg.discord.enable && cfg.discord.installPackage) [ cfg.finalPackage.discord ])
          (mkIf (cfg.vesktop.enable && cfg.vesktop.installPackage) [ cfg.finalPackage.vesktop ])
          (mkIf (cfg.equibop.enable && cfg.finalPackage.equibop != null && cfg.equibop.installPackage) [
            cfg.finalPackage.equibop
          ])
          (mkIf (cfg.dorion.enable && cfg.dorion.installPackage) [ cfg.finalPackage.dorion ])
        ];
      }
      (mkIf cfg.discord.enable (mkMerge [
        {
          home.activation.disableDiscordUpdates = activationScripts.disableDiscordUpdates;
          home.activation.fixDiscordModules = activationScripts.fixDiscordModules;
        }
        (mkIf (isQuickCssUsed cfg.vencordConfig || isQuickCssUsed cfg.equicordConfig) {
          home.file."${cfg.configDir}/settings/quickCss.css".text = cfg.quickCss;
        })
        (mkIf cfg.discord.vencord.enable {
          home.file."${cfg.configDir}/settings/settings.json".text = builtins.toJSON (
            mkVencordCfg vencordFullConfig
          );
        })
        (mkIf cfg.discord.equicord.enable {
          home.file."${cfg.configDir}/settings/settings.json".text = builtins.toJSON (
            mkVencordCfg equicordFullConfig
          );
        })
        (mkIf (cfg.discord.settings != { }) {
          home.file."${cfg.discord.configDir}/settings.json".text = builtins.toJSON (
            mkVencordCfg cfg.discord.settings
          );
        })
      ]))
      (mkIf cfg.vesktop.enable (mkMerge [
        (mkIf (isQuickCssUsed cfg.vesktopConfig) {
          home.file."${cfg.vesktop.configDir}/settings/quickCss.css".text = cfg.quickCss;
        })
        {
          home.file."${cfg.vesktop.configDir}/settings/settings.json".text = builtins.toJSON (
            mkVencordCfg vesktopFullConfig
          );
        }
        (mkIf (cfg.vesktop.settings != { }) {
          home.file."${cfg.vesktop.configDir}/settings.json".text = builtins.toJSON (
            mkVencordCfg cfg.vesktop.settings
          );
        })
        (mkIf (cfg.vesktop.state != { }) {
          home.file."${cfg.vesktop.configDir}/state.json".text = builtins.toJSON (
            mkVencordCfg cfg.vesktop.state
          );
        })
        (mkIf (cfg.config.themes != { }) {
          home.file = lib.mapAttrs' (
            name: value:
            lib.nameValuePair "${cfg.vesktop.configDir}/themes/${name}.css" {
              text = if builtins.isPath value || lib.isStorePath value then builtins.readFile value else value;
            }
          ) cfg.config.themes;
        })
      ]))
      (mkIf cfg.equibop.enable (mkMerge [
        (mkIf (isQuickCssUsed cfg.equibopConfig) {
          home.file."${cfg.equibop.configDir}/settings/quickCss.css".text = cfg.quickCss;
        })
        {
          home.file."${cfg.equibop.configDir}/settings/settings.json".text = builtins.toJSON (
            mkVencordCfg equibopFullConfig
          );
        }
        (mkIf (cfg.equibop.settings != { }) {
          home.file."${cfg.equibop.configDir}/settings.json".text = builtins.toJSON (
            mkVencordCfg cfg.equibop.settings
          );
        })
        (mkIf (cfg.equibop.state != { }) {
          home.file."${cfg.equibop.configDir}/state.json".text = builtins.toJSON (
            mkVencordCfg cfg.equibop.state
          );
        })
        (mkIf (cfg.config.themes != { }) {
          home.file = lib.mapAttrs' (
            name: value:
            lib.nameValuePair "${cfg.equibop.configDir}/themes/${name}.css" {
              text = if builtins.isPath value || lib.isStorePath value then builtins.readFile value else value;
            }
          ) cfg.config.themes;
        })
      ]))
      (mkIf cfg.dorion.enable (mkMerge [
        {
          home.file."${cfg.dorion.configDir}/config.json".text = builtins.toJSON (mkDorionConfigAttrs {
            inherit cfg;
          });
        }
        {
          home.activation.setupDorionVencordSettings = activationScripts.setupDorionVencordSettings;
        }
      ]))
    ])
  );
}
