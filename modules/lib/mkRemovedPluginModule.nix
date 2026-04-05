# mkRemovedPluginModule :: string -> NixOS module
#
# Generates a backward-compatible shim for a plugin that was removed
# upstream. The shim accepts (and ignores) the old option, and emits a
# warning when the user still has `enable = true`.
{ lib }:
pluginName:
{ config, ... }:
{
  options.programs.nixcord.config.plugins.${pluginName} = lib.mkOption {
    type = lib.types.anything;
    default = { };
    visible = false;
    description = "REMOVED: Plugin '${pluginName}' was removed upstream.";
  };
  config.warnings =
    lib.optional (config.programs.nixcord.config.plugins.${pluginName}.enable or false)
      "Plugin '${pluginName}' has been removed upstream. Please remove it from your nixcord configuration. This shim will be removed soon.";
}
