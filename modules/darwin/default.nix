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
    mkCopyCommands
    mkSettingsFiles
    mkDorionConfigAttrs
    mkThemeFile
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
      inherit (settingsFiles)
        vencordSettingsFile
        equicordSettingsFile
        discordSettingsFile
        vesktopSettingsFile
        vesktopClientSettingsFile
        vesktopStateFile
        equibopSettingsFile
        equibopClientSettingsFile
        equibopStateFile
        ;

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

      homeDir = "/Users/${cfg.user}";
      basePath = "${homeDir}/Library/Application Support";

      isQuickCssUsed = mkIsQuickCssUsed { inherit cfg; };

      activationScripts = import ../lib/activation.nix {
        inherit
          lib
          pkgs
          cfg
          mkVencordCfg
          ;
        wrapScript = script: ''
          ${script}
        '';
      };

      install = lib.getExe' pkgs.coreutils "install";

      fileCommands = mkCopyCommands {
        inherit
          lib
          cfg
          quickCssFile
          vencordSettingsFile
          equicordSettingsFile
          discordSettingsFile
          vesktopSettingsFile
          vesktopClientSettingsFile
          vesktopStateFile
          vesktopThemes
          equibopSettingsFile
          equibopClientSettingsFile
          equibopStateFile
          dorionConfigFile
          isQuickCssUsed
          ;
      };

    in
    mkMerge ([
      {
        programs.nixcord =
          (mkConfigDirs {
            inherit cfg;
            inherit basePath;
          })
          // {
            # Darwin dorion uses ~/.config instead of ~/Library/Application Support
            dorion.configDir = lib.mkDefault "${homeDir}/.config/dorion";
          };
      }
      {
        programs.nixcord.finalPackage = mkFinalPackages {
          inherit cfg;
          vencord = applyPostPatch {
            inherit cfg;
            pkg = cfg.discord.vencord.package;
          };
          equicord = applyPostPatch {
            inherit cfg;
            pkg = cfg.discord.equicord.package;
          };
        };

        environment.systemPackages = mkMerge [
          (mkIf (cfg.discord.enable && cfg.discord.installPackage) [ cfg.finalPackage.discord ])
          (mkIf (cfg.vesktop.enable && cfg.vesktop.installPackage) [ cfg.finalPackage.vesktop ])
          (mkIf (cfg.equibop.enable && cfg.finalPackage.equibop != null && cfg.equibop.installPackage) [
            cfg.finalPackage.equibop
          ])
          (mkIf (cfg.dorion.enable && cfg.dorion.installPackage) [ cfg.finalPackage.dorion ])
        ];
      }
      (mkIf cfg.discord.enable {
        system.activationScripts.nixcord-disableDiscordUpdates.text =
          activationScripts.disableDiscordUpdates;
        system.activationScripts.nixcord-fixDiscordModules.text = activationScripts.fixDiscordModules;
      })
      (mkIf (cfg.discord.enable || cfg.vesktop.enable || cfg.equibop.enable || cfg.dorion.enable) {
        system.activationScripts.applications.text = lib.mkAfter (
          let
            mkDir = dir: "${install} -d -o ${lib.escapeShellArg cfg.user} -g staff ${lib.escapeShellArg dir}";
          in
          ''
            ${mkDir cfg.configDir}
            ${lib.optionalString cfg.discord.enable (mkDir cfg.discord.configDir)}
            ${lib.optionalString cfg.vesktop.enable (mkDir cfg.vesktop.configDir)}
            ${lib.optionalString cfg.equibop.enable (mkDir cfg.equibop.configDir)}
            ${lib.optionalString cfg.dorion.enable (mkDir cfg.dorion.configDir)}

            copy_file() {
              sudo --user=${lib.escapeShellArg cfg.user} -- ${install} -D -m "$3" "$1" "$2"
            }

            ${fileCommands}
          ''
        );
      })
      (mkIf cfg.dorion.enable {
        system.activationScripts.nixcord-setupDorionVencordSettings.text =
          activationScripts.setupDorionVencordSettings;
      })
    ])
  );
}
