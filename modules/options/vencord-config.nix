{ lib, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.programs.nixcord = {
    quickCss = mkOption {
      type = types.str;
      default = "";
      description = "Vencord quick CSS";
    };
    config = {
      notifyAboutUpdates = mkEnableOption "Notify when updates are available";
      autoUpdate = mkEnableOption "Automaticall update Vencord";
      autoUpdateNotification = mkEnableOption "Notify user about auto updates";
      useQuickCss = mkEnableOption "Enable quick CSS file";
      themeLinks = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "A list of links to online vencord themes";
        example = [ "https://raw.githubusercontent.com/rose-pine/discord/main/rose-pine.theme.css" ];
      };
      themes = mkOption {
        type = types.attrsOf (
          types.oneOf [
            types.lines
            types.path
          ]
        );
        default = { };
        description = ''
          Themes to add, they can be enabled by settings
          `programs.nixcord.config.enabledThemes` to `[ "THEME_NAME.css" ]`
        '';
      };
      enabledThemes = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "A list of themes to enable from themes directory";
      };
      enableReactDevtools = mkEnableOption "Enable React developer tools";
      frameless = mkEnableOption "Make client frameless";
      transparent = mkEnableOption "Enable client transparency";
      disableMinSize = mkEnableOption "Disable minimum window size for client";
      plugins =
        lib.recursiveUpdate
          (lib.recursiveUpdate
            (import ../plugins/mkPluginOptions.nix {
              inherit lib;
              file = ../plugins/shared.json;
            })
            (
              import ../plugins/mkPluginOptions.nix {
                inherit lib;
                file = ../plugins/vencord.json;
              }
            )
          )
          (
            import ../plugins/mkPluginOptions.nix {
              inherit lib;
              file = ../plugins/equicord.json;
            }
          );
    };
  };
}
