{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.programs.nixcord = {
    vesktopConfig = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        additional config to be added to programs.nixcord.config
        for vesktop only
      '';
    };
    equibopConfig = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        additional config to be added to programs.nixcord.config
        for equibop only
      '';
    };
    vencordConfig = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        additional config to be added to programs.nixcord.config
        for vencord only
      '';
    };
    equicordConfig = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        additional config to be added to programs.nixcord.config
        for equicord only
      '';
    };
    extraConfig = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        additional config to be added to programs.nixcord.config
        for both vencord and vesktop
      '';
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
        description = "User plugin to fetch and install. Note that any json required must be enabled in extraConfig";
        default = { };
        example = {
          someCoolPlugin = "github:someUser/someCoolPlugin/someHashHere";
        };
      };
    parseRules = {
      upperNames = mkOption {
        type = types.listOf types.str;
        description = "option names to become UPPER_SNAKE_CASE";
        default = [ ];
      };
      lowerPluginTitles = mkOption {
        type = types.listOf types.str;
        description = "plugins with lowercase names in json";
        default = [ ];
        example = [ "petpet" ];
      };
    };
  };
}
