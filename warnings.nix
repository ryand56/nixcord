{
  cfg,
  mkIf,
  lib,
  deprecatedPlugins ? [ ],
  pluginNameMigrations ? { },
}:
let
  generateMigrationWarning =
    oldName:
    let
      newName = pluginNameMigrations.${oldName} or null;
    in
    if newName != null then
      "'${oldName}' has been renamed to '${newName}'. The old name will continue to work for now but will be removed in a future update. Please update your config to use '${newName}'."
    else
      "'${oldName}' is deprecated. Please check the documentation for the new name";

  warnings = lib.map generateMigrationWarning deprecatedPlugins;
in
warnings
