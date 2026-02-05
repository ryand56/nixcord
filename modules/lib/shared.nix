{ lib }:

let
  mergeAttrsList = list: builtins.foldl' lib.recursiveUpdate { } list;

  applyPostPatch =
    { cfg, pkg }:
    pkg.overrideAttrs (o: {
      postPatch =
        (o.postPatch or "")
        + lib.concatLines (
          lib.optional (cfg.userPlugins != { }) "mkdir -p src/userplugins"
          ++ lib.mapAttrsToList (
            name: path: "ln -s ${lib.escapeShellArg path} src/userplugins/${lib.escapeShellArg name}"
          ) cfg.userPlugins
        );

      postInstall = (o.postInstall or "") + ''
        cp package.json "$out"
      '';
    });

  mkIsQuickCssUsed =
    { cfg }:
    appConfig: (cfg.config.useQuickCss || (appConfig.useQuickCss or false)) && cfg.quickCss != "";

  mkPluginKit =
    { cfg }:
    let
      sharedPlugins = import ../plugins/shared.nix { inherit lib; };
      vencordOnlyPlugins = import ../plugins/vencord.nix { inherit lib; };
      equicordOnlyPlugins = import ../plugins/equicord.nix { inherit lib; };
      deprecated = import ../plugins/deprecated.nix;
      pluginNameMigrations = lib.mapAttrs (_: v: v.to) (deprecated.renames or { });

      isPluginEnabled = pluginConfig: pluginConfig.enable or false;

      collectDeprecatedPlugins =
        configAttrs:
        let
          plugins = configAttrs.plugins or { };
        in
        lib.filter (oldName: builtins.hasAttr oldName plugins && isPluginEnabled plugins.${oldName}) (
          builtins.attrNames pluginNameMigrations
        );

      collectEnabledEquicordOnlyPlugins =
        configAttrs:
        let
          plugins = configAttrs.plugins or { };
          sharedNames = builtins.attrNames sharedPlugins;
          vencordNames = builtins.attrNames vencordOnlyPlugins;
          equicordNames = builtins.attrNames equicordOnlyPlugins;
          allowedEquicordOnly = lib.filter (
            name: !(builtins.elem name sharedNames) && !(builtins.elem name vencordNames)
          ) equicordNames;
        in
        builtins.attrNames (
          lib.filterAttrs (
            name: value: builtins.elem name allowedEquicordOnly && isPluginEnabled value
          ) plugins
        );

      collectEnabledVencordOnlyPlugins =
        configAttrs:
        let
          plugins = configAttrs.plugins or { };
          sharedNames = builtins.attrNames sharedPlugins;
          vencordNames = builtins.attrNames vencordOnlyPlugins;
          equicordNames = builtins.attrNames equicordOnlyPlugins;
          allowedVencordOnly = lib.filter (
            name: !(builtins.elem name sharedNames) && !(builtins.elem name equicordNames)
          ) vencordNames;
        in
        builtins.attrNames (
          lib.filterAttrs (
            name: value: builtins.elem name allowedVencordOnly && isPluginEnabled value
          ) plugins
        );

      filterPluginsFor =
        client: configAttrs:
        let
          allowedNames =
            builtins.attrNames sharedPlugins
            ++ (if client == "vencord" then builtins.attrNames vencordOnlyPlugins
                else if client == "equicord" then builtins.attrNames equicordOnlyPlugins
                else []);
          mask = lib.genAttrs allowedNames (_: null);
          plugins = configAttrs.plugins or { };
        in
        configAttrs // { plugins = builtins.intersectAttrs mask plugins; };

      filterPluginsForClient =
        configAttrs:
        filterPluginsFor
          (if cfg.discord.vencord.enable then "vencord"
           else if cfg.discord.equicord.enable then "equicord"
           else "none")
          configAttrs;

      mkFullConfig =
        {
          baseConfig,
          extraConfig ? { },
          clientConfig ? { },
        }:
        let
          filteredBaseConfig = filterPluginsForClient baseConfig;
        in
        mergeAttrsList [
          filteredBaseConfig
          extraConfig
          clientConfig
        ];
    in
    {
      inherit
        sharedPlugins
        vencordOnlyPlugins
        equicordOnlyPlugins
        pluginNameMigrations
        collectDeprecatedPlugins
        collectEnabledEquicordOnlyPlugins
        collectEnabledVencordOnlyPlugins
        filterPluginsFor
        filterPluginsForClient
        mkFullConfig
        ;
    };

  mkCopyCommands =
    {
      lib,
      cfg,
      quickCssFile,
      vencordSettingsFile,
      equicordSettingsFile,
      discordSettingsFile,
      vesktopSettingsFile,
      vesktopClientSettingsFile,
      vesktopStateFile,
      vesktopThemes,
      equibopSettingsFile,
      equibopClientSettingsFile,
      equibopStateFile,
      dorionConfigFile,
      isQuickCssUsed,
    }:
    let
      mkCopy = src: dest: "copy_file ${src} ${lib.escapeShellArg dest} 0644";

      quickCssEnabled = cfg.quickCss != "";
      quickCssOnDiscord =
        cfg.discord.enable
        && quickCssEnabled
        && lib.any isQuickCssUsed [
          cfg.vencordConfig
          cfg.equicordConfig
        ];
      quickCssOnVesktop = cfg.vesktop.enable && quickCssEnabled && isQuickCssUsed cfg.vesktopConfig;
      quickCssOnEquibop = cfg.equibop.enable && quickCssEnabled && isQuickCssUsed cfg.equibopConfig;

      discordCopies =
        lib.optionals quickCssOnDiscord [
          (mkCopy quickCssFile "${cfg.configDir}/settings/quickCss.css")
        ]
        ++ lib.optionals cfg.discord.vencord.enable [
          (mkCopy vencordSettingsFile "${cfg.configDir}/settings/settings.json")
        ]
        ++ lib.optionals cfg.discord.equicord.enable [
          (mkCopy equicordSettingsFile "${cfg.configDir}/settings/settings.json")
        ]
        ++ lib.optionals (cfg.discord.settings != { }) [
          (mkCopy discordSettingsFile "${cfg.discord.configDir}/settings.json")
        ];

      vesktopCopies =
        lib.optionals cfg.vesktop.enable [
          (mkCopy vesktopSettingsFile "${cfg.vesktop.configDir}/settings/settings.json")
        ]
        ++ lib.optionals (cfg.vesktop.enable && vesktopClientSettingsFile != null) [
          (mkCopy vesktopClientSettingsFile "${cfg.vesktop.configDir}/settings.json")
        ]
        ++ lib.optionals (cfg.vesktop.enable && vesktopStateFile != null) [
          (mkCopy vesktopStateFile "${cfg.vesktop.configDir}/state.json")
        ]
        ++ lib.optionals cfg.vesktop.enable [
          lib.mapAttrsToList
          (name: path: mkCopy path "${cfg.vesktop.configDir}/themes/${name}.css")
          vesktopThemes
        ]
        ++ lib.optionals quickCssOnVesktop [
          (mkCopy quickCssFile "${cfg.vesktop.configDir}/settings/quickCss.css")
        ];

      equibopCopies =
        lib.optionals cfg.equibop.enable [
          (mkCopy equibopSettingsFile "${cfg.equibop.configDir}/settings/settings.json")
        ]
        ++ lib.optionals (cfg.equibop.enable && equibopClientSettingsFile != null) [
          (mkCopy equibopClientSettingsFile "${cfg.equibop.configDir}/settings.json")
        ]
        ++ lib.optionals (cfg.equibop.enable && equibopStateFile != null) [
          (mkCopy equibopStateFile "${cfg.equibop.configDir}/state.json")
        ]
        ++ lib.optionals quickCssOnEquibop [
          (mkCopy quickCssFile "${cfg.equibop.configDir}/settings/quickCss.css")
        ];

      dorionCopies = lib.optionals (cfg.dorion.enable && dorionConfigFile != null) [
        (mkCopy dorionConfigFile "${cfg.dorion.configDir}/config.json")
      ];
    in
    lib.concatMapStringsSep "\n" lib.id (
      discordCopies ++ vesktopCopies ++ equibopCopies ++ dorionCopies
    );
in
{
  inherit
    mergeAttrsList
    applyPostPatch
    mkIsQuickCssUsed
    mkPluginKit
    mkCopyCommands
    ;
}
