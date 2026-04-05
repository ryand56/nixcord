{ lib }:

let
  # mergeAttrsList :: [attrset] -> attrset
  # Deep-merge a list of attribute sets (left to right).
  mergeAttrsList = list: builtins.foldl' lib.recursiveUpdate { } list;

  # applyPostPatch :: { cfg, pkg } -> derivation
  # Patch a Vencord/Equicord derivation to include user plugins.
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

  # mkIsQuickCssUsed :: { cfg } -> attrset -> bool
  # Returns whether quick CSS should be written for a given client config.
  mkIsQuickCssUsed =
    { cfg }:
    appConfig: (cfg.config.useQuickCss || (appConfig.useQuickCss or false)) && cfg.quickCss != "";

  # mkPluginKit :: { cfg } -> { filterPluginsFor, mkFullConfig, ... }
  # Builds plugin filtering and config merging utilities for the given configuration.
  mkPluginKit =
    { cfg }:
    let
      sharedPlugins = import ../plugins/mkPluginOptions.nix {
        inherit lib;
        file = ../plugins/shared.json;
      };
      vencordOnlyPlugins = import ../plugins/mkPluginOptions.nix {
        inherit lib;
        file = ../plugins/vencord.json;
      };
      equicordOnlyPlugins = import ../plugins/mkPluginOptions.nix {
        inherit lib;
        file = ../plugins/equicord.json;
      };
      deprecated = builtins.fromJSON (builtins.readFile ../plugins/deprecated.json);
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
            ++ (
              if client == "vencord" then
                builtins.attrNames vencordOnlyPlugins
              else if client == "equicord" then
                builtins.attrNames equicordOnlyPlugins
              else
                [ ]
            );
          mask = lib.genAttrs allowedNames (_: null);
          plugins = configAttrs.plugins or { };
        in
        configAttrs // { plugins = builtins.intersectAttrs mask plugins; };

      filterPluginsForClient =
        configAttrs:
        filterPluginsFor (
          if cfg.discord.vencord.enable then
            "vencord"
          else if cfg.discord.equicord.enable then
            "equicord"
          else
            "none"
        ) configAttrs;

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

  # mkCopyCommands :: { lib, cfg, ...files } -> string
  # Generates shell commands to copy all settings/theme files to their destinations.
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
  # toSnakeCase :: string -> string
  # Converts a camelCase string to snake_case.
  toSnakeCase =
    str:
    lib.pipe str [
      (builtins.split "([A-Z])")
      (builtins.foldl' (
        acc: part:
        if builtins.isList part then acc + "_" + (lib.toLower (builtins.elemAt part 0)) else acc + part
      ) "")
      (builtins.replaceStrings [ "__" ] [ "_" ])
    ];

  # mkDorionConfigAttrs :: { cfg } -> attrset
  # Builds the Dorion config.json attribute set from module options.
  mkDorionConfigAttrs =
    { cfg }:
    let
      dorionConfig = {
        autoupdate = false;
      }
      // (lib.mapAttrs' (name: value: {
        name = toSnakeCase name;
        inherit value;
      }) (builtins.removeAttrs cfg.dorion [ "extraSettings" ]));
    in
    dorionConfig // cfg.dorion.extraSettings;

  # mkAssertions :: { cfg, collectEnabledEquicordOnlyPlugins, collectEnabledVencordOnlyPlugins } -> [assertion]
  # Generates NixOS assertions for mutually-exclusive client and plugin constraints.
  mkAssertions =
    {
      cfg,
      collectEnabledEquicordOnlyPlugins,
      collectEnabledVencordOnlyPlugins,
    }:
    let
      allPlugins = {
        plugins =
          (cfg.config.plugins or { })
          // (cfg.extraConfig.plugins or { })
          // (cfg.vencordConfig.plugins or { })
          // (cfg.equicordConfig.plugins or { })
          // (cfg.vesktopConfig.plugins or { })
          // (cfg.equibopConfig.plugins or { });
      };
      wrongEquicordPlugins = collectEnabledEquicordOnlyPlugins allPlugins;
      wrongVencordPlugins = collectEnabledVencordOnlyPlugins allPlugins;
      hasVencordClient = cfg.discord.vencord.enable || cfg.vesktop.enable;
      hasEquicordClient = cfg.discord.equicord.enable || cfg.equibop.enable;
    in
    [
      {
        assertion = !(cfg.discord.vencord.enable && cfg.discord.equicord.enable);
        message = "programs.nixcord.discord.vencord.enable and programs.nixcord.discord.equicord.enable cannot both be enabled at the same time. They are mutually exclusive.";
      }
      {
        assertion = !(hasVencordClient && !hasEquicordClient) || wrongEquicordPlugins == [ ];
        message = "The following Equicord-only plugins are enabled but only Vencord-based clients are active: ${lib.concatStringsSep ", " wrongEquicordPlugins}. These plugins are not available in Vencord.";
      }
      {
        assertion = !(hasEquicordClient && !hasVencordClient) || wrongVencordPlugins == [ ];
        message = "The following Vencord-only plugins are enabled but only Equicord-based clients are active: ${lib.concatStringsSep ", " wrongVencordPlugins}. These plugins are not available in Equicord.";
      }
    ];

  # mkSettingsFiles :: { pkgs, cfg, mkVencordCfg, ...configs } -> { *File :: path | null }
  # Creates derivations for all client settings/state JSON files.
  mkSettingsFiles =
    {
      pkgs,
      cfg,
      mkVencordCfg,
      vencordFullConfig,
      equicordFullConfig,
      vesktopFullConfig,
      equibopFullConfig,
    }:
    {
      vencordSettingsFile = pkgs.writeText "nixcord-settings.json" (
        builtins.toJSON (mkVencordCfg vencordFullConfig)
      );
      equicordSettingsFile = pkgs.writeText "nixcord-equicord-settings.json" (
        builtins.toJSON (mkVencordCfg equicordFullConfig)
      );
      discordSettingsFile =
        if cfg.discord.settings != { } then
          pkgs.writeText "nixcord-discord-settings.json" (builtins.toJSON (mkVencordCfg cfg.discord.settings))
        else
          null;
      vesktopSettingsFile = pkgs.writeText "nixcord-vesktop-settings.json" (
        builtins.toJSON (mkVencordCfg vesktopFullConfig)
      );
      vesktopClientSettingsFile =
        if cfg.vesktop.settings != { } then
          pkgs.writeText "nixcord-vesktop-client-settings.json" (
            builtins.toJSON (mkVencordCfg cfg.vesktop.settings)
          )
        else
          null;
      vesktopStateFile =
        if cfg.vesktop.state != { } then
          pkgs.writeText "nixcord-vesktop-state.json" (builtins.toJSON (mkVencordCfg cfg.vesktop.state))
        else
          null;
      equibopSettingsFile = pkgs.writeText "nixcord-equibop-settings.json" (
        builtins.toJSON (mkVencordCfg equibopFullConfig)
      );
      equibopClientSettingsFile =
        if cfg.equibop.settings != { } then
          pkgs.writeText "nixcord-equibop-client-settings.json" (
            builtins.toJSON (mkVencordCfg cfg.equibop.settings)
          )
        else
          null;
      equibopStateFile =
        if cfg.equibop.state != { } then
          pkgs.writeText "nixcord-equibop-state.json" (builtins.toJSON (mkVencordCfg cfg.equibop.state))
        else
          null;
    };

  # mkThemeFile :: { pkgs } -> string -> (path | string) -> path
  # Resolves a theme value to a store path (either a direct path or a writeText derivation).
  mkThemeFile =
    { pkgs }:
    name: value:
    if builtins.isPath value || lib.isStorePath value then
      value
    else
      pkgs.writeText "nixcord-theme-${name}.css" value;

in
{
  inherit
    mergeAttrsList
    applyPostPatch
    mkIsQuickCssUsed
    mkPluginKit
    mkCopyCommands
    toSnakeCase
    mkDorionConfigAttrs
    mkAssertions
    mkSettingsFiles
    mkThemeFile
    ;
}
