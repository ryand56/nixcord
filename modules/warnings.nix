# Shared validation: warnings for deprecated/renamed plugins and assertions
# for mutually-exclusive client options.
{
  config,
  lib,
  ...
}:
let
  cfg = config.programs.nixcord;

  inherit (import ./lib/shared.nix { inherit lib; })
    mkPluginKit
    mkAssertions
    ;

  pluginKit = mkPluginKit { inherit cfg; };

  inherit (pluginKit)
    pluginNameMigrations
    collectDeprecatedPlugins
    collectEnabledEquicordOnlyPlugins
    collectEnabledVencordOnlyPlugins
    ;

  allPlugins = {
    plugins =
      (cfg.config.plugins or { })
      // (cfg.extraConfig.plugins or { })
      // (cfg.vencordConfig.plugins or { })
      // (cfg.equicordConfig.plugins or { })
      // (cfg.vesktopConfig.plugins or { })
      // (cfg.equibopConfig.plugins or { });
  };

  deprecatedPlugins = collectDeprecatedPlugins allPlugins;

  generateMigrationWarning =
    oldName:
    let
      newName = pluginNameMigrations.${oldName} or null;
    in
    if newName != null then
      "'${oldName}' has been renamed to '${newName}'. The old name will continue to work for now but will be removed in a future update. Please update your config to use '${newName}'."
    else
      "'${oldName}' is deprecated. Please check the documentation for the new name";
in
{
  config = lib.mkIf cfg.enable {
    warnings = lib.map generateMigrationWarning deprecatedPlugins;

    assertions = mkAssertions {
      inherit cfg collectEnabledEquicordOnlyPlugins collectEnabledVencordOnlyPlugins;
    };
  };
}
