{
  config,
  lib,
  pkgs,
  nixcordPkgs ? { },
  ...
}:
let
  inherit (lib)
    mkIf
    mkMerge
    types
    ;

  inherit (pkgs.callPackage ../lib/shared.nix { inherit lib; })
    mergeAttrsList
    applyPostPatch
    mkIsQuickCssUsed
    mkPluginKit
    mkCopyCommands
    mkAssertions
    mkSettingsFiles
    mkDorionConfigAttrs
    mkThemeFile
    ;

  dop = with types; coercedTo package (a: a.outPath) pathInStore;

in
{
  imports = [ ../plugins/migrations.nix ];

  options.programs.nixcord = import ../options.nix {
    inherit
      lib
      pkgs
      dop
      applyPostPatch
      nixcordPkgs
      ;
  };

  config = mkIf config.programs.nixcord.enable (
    let
      cfg = config.programs.nixcord;

      parseRules = cfg.parseRules;
      inherit (pkgs.callPackage ../lib/core.nix { inherit lib parseRules; }) mkVencordCfg mkFinalPackages;

      isQuickCssUsed = mkIsQuickCssUsed { inherit cfg; };

      pluginKit = mkPluginKit { inherit cfg; };

      inherit (pluginKit)
        pluginNameMigrations
        collectDeprecatedPlugins
        collectEnabledEquicordOnlyPlugins
        collectEnabledVencordOnlyPlugins
        filterPluginsFor
        mkFullConfig
        ;

      vencordFullConfig = mkFullConfig {
        baseConfig = cfg.config;
        extraConfig = cfg.extraConfig;
        clientConfig = cfg.vencordConfig;
      };

      equicordFullConfig = mkFullConfig {
        baseConfig = cfg.config;
        extraConfig = cfg.extraConfig;
        clientConfig = cfg.equicordConfig;
      };

      vesktopFullConfig = filterPluginsFor "vencord" (mergeAttrsList [
        cfg.config
        cfg.extraConfig
        cfg.vesktopConfig
      ]);

      equibopFullConfig = filterPluginsFor "equicord" (mergeAttrsList [
        cfg.config
        cfg.extraConfig
        cfg.equibopConfig
      ]);

      quickCssFile = pkgs.writeText "nixcord-quickcss.css" cfg.quickCss;

      settingsFiles = mkSettingsFiles {
        inherit pkgs cfg mkVencordCfg vencordFullConfig equicordFullConfig vesktopFullConfig equibopFullConfig;
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
            builtins.toJSON (mkDorionConfigAttrs { inherit cfg; })
          )
        else
          null;

      activationScripts = import ../lib/activation.nix {
        inherit
          lib
          pkgs
          cfg
          mkVencordCfg
          ;
        wrapScript = script: ''
          ${lib.getExe' pkgs.util-linux "runuser"} -u ${lib.escapeShellArg cfg.user} -- /bin/sh -c ${lib.escapeShellArg script}
        '';
      };

      writeFilesScript =
        let
          install = lib.getExe' pkgs.coreutils "install";
          idBin = lib.getExe' pkgs.coreutils "id";

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
        ''
          set -euo pipefail

          target_user=${lib.escapeShellArg cfg.user}
          target_group_default=${lib.escapeShellArg null}
          target_group="$target_group_default"
          if [ -z "$target_group" ]; then
            target_group="$(${idBin} -gn "$target_user")"
          fi

          copy_file() {
            local src="$1"
            local dest="$2"
            local mode="$3"
            ${install} -D -m "$mode" -o "$target_user" -g "$target_group" "$src" "$dest"
          }

          ${fileCommands}
        '';
    in
    mkMerge ([
      {
        programs.nixcord.homeDirectory = "/home/${cfg.user}";
        programs.nixcord.xdgConfigHome = "${"/home/${cfg.user}"}/.config";

        programs.nixcord.discord.configDir = lib.mkDefault (
          let
            basePath = cfg.xdgConfigHome;
            branchDirName =
              {
                stable = "discord";
                ptb = "discordptb";
                canary = "discordcanary";
                development = "discorddevelopment";
              }
              .${cfg.discord.branch} or "discord";
          in
          "${basePath}/${branchDirName}"
        );
        programs.nixcord.configDir = lib.mkDefault (
          let
            basePath = cfg.xdgConfigHome;
            dirName = if cfg.discord.equicord.enable then "Equicord" else "Vencord";
          in
          "${basePath}/${dirName}"
        );
        programs.nixcord.vesktop.configDir = lib.mkDefault "${cfg.xdgConfigHome}/vesktop";
        programs.nixcord.equibop.configDir = lib.mkDefault "${cfg.xdgConfigHome}/equibop";
        programs.nixcord.dorion.configDir = lib.mkDefault "${cfg.xdgConfigHome}/dorion";

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
        system.activationScripts.nixcord-disableDiscordUpdates = {
          text = activationScripts.disableDiscordUpdates;
          supportsDryActivation = false;
        };
        system.activationScripts.nixcord-fixDiscordModules = {
          text = activationScripts.fixDiscordModules;
          supportsDryActivation = false;
        };
      })
      (mkIf cfg.dorion.enable {
        system.activationScripts.nixcord-setupDorionVencordSettings = {
          text = activationScripts.setupDorionVencordSettings;
          supportsDryActivation = false;
        };
      })
      (mkIf (cfg.discord.enable || cfg.vesktop.enable || cfg.equibop.enable || cfg.dorion.enable) {
        system.activationScripts.nixcord-writeFiles = {
          text = writeFilesScript;
          supportsDryActivation = false;
        };
      })
      {
        warnings = import ../../warnings.nix {
          inherit
            cfg
            mkIf
            lib
            pluginNameMigrations
            ;
          deprecatedPlugins = collectDeprecatedPlugins cfg.config;
        };

        assertions = mkAssertions {
          inherit cfg collectEnabledEquicordOnlyPlugins collectEnabledVencordOnlyPlugins;
        };
      }
    ])
  );
}
