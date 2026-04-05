{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.programs.nixcord = {
    vesktopConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional config merged into `programs.nixcord.config` for Vesktop only.";
    };
    equibopConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional config merged into `programs.nixcord.config` for Equibop only.";
    };
    vencordConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional config merged into `programs.nixcord.config` for Vencord (Discord) only.";
    };
    equicordConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional config merged into `programs.nixcord.config` for Equicord (Discord) only.";
    };
    extraConfig = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional config merged into `programs.nixcord.config` for all clients.";
    };
    userPlugins =
      let
        regex = "github:([[:alnum:].-]+)/([[:alnum:]/-]+)/([0-9a-f]{40})";
        coerce =
          value:
          let
            matches = builtins.match regex value;
            owner = builtins.elemAt matches 0;
            repo = builtins.elemAt matches 1;
            rev = builtins.elemAt matches 2;
          in
          builtins.fetchGit {
            url = "https://github.com/${owner}/${repo}";
            inherit rev;
          };
      in
      mkOption {
        type = types.attrsOf (types.coercedTo (types.strMatching regex) coerce types.dop);
        description = "User plugins to fetch and install. Any required JSON config must be enabled in `extraConfig`.";
        default = { };
        example = {
          someCoolPlugin = "github:someUser/someCoolPlugin/someHashHere";
        };
      };
    parseRules = {
      upperNames = mkOption {
        type = types.listOf types.str;
        description = "Option names that should be converted to UPPER_SNAKE_CASE in generated JSON.";
        default = [ ];
      };
      lowerPluginTitles = mkOption {
        type = types.listOf types.str;
        description = "Plugin names that should remain lowercase in generated JSON.";
        default = [ ];
        example = [ "petpet" ];
      };
    };
  };
}
