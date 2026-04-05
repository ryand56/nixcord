{
  lib,
  parseRules,
  libva,
  stdenv,
  electron_40,
  ...
}:
let
  inherit (lib)
    attrsets
    lists
    strings
    ;

  inherit (attrsets)
    mapAttrs'
    nameValuePair
    ;

  defaultParseRules = builtins.fromJSON (builtins.readFile ../plugins/parse-rules.json);

  mergeLists = base: extra: lists.unique (base ++ extra);

  upperNames = mergeLists defaultParseRules.upperNames parseRules.upperNames;
  lowerPluginTitles = mergeLists defaultParseRules.lowerPluginTitles parseRules.lowerPluginTitles;
  mergeSettingRenames =
    base: extra:
    let
      allKeys = builtins.attrNames base ++ builtins.attrNames extra;
    in
    builtins.listToAttrs (
      map (key: {
        name = key;
        value = (base.${key} or { }) // (extra.${key} or { });
      }) (lists.unique allKeys)
    );
  settingRenames = mergeSettingRenames (defaultParseRules.settingRenames or { }) (
    parseRules.settingRenames or { }
  );

  isLowerCase = s: strings.toLower s == s;

  unNixify =
    nixName:
    strings.toUpper (
      strings.concatStrings (
        builtins.map (char: if isLowerCase char then char else "_" + char) (
          strings.stringToCharacters nixName
        )
      )
    );

  isLowerCamel = string: isLowerCase (builtins.substring 0 1 string);

  toUpper =
    string:
    strings.concatStrings [
      (strings.toUpper (builtins.substring 0 1 string))
      (builtins.substring 1 (builtins.stringLength string) string)
    ];

  specialRenames = {
    enable = "enabled";
    tagSettings = "tagSettings";
    useQuickCss = "useQuickCSS";
    webRichPresence = "WebRichPresence (arRPC)";
    _24hTime = "24h Time";
    showOwnTimezone = "Show Own Timezone";
  };

  normalizeName =
    context: name: value:
    if specialRenames ? ${name} then
      specialRenames.${name}
    else if settingRenames ? ${context} && settingRenames.${context} ? ${name} then
      settingRenames.${context}.${name}
    else if builtins.elem name upperNames then
      unNixify name
    else if builtins.elem name lowerPluginTitles then
      name
    else if builtins.isAttrs value && value ? enable && isLowerCamel name then
      toUpper name
    else
      name;

  mkVencordCfgInner =
    context: cfg:
    mapAttrs' (
      name: value:
      let
        normalizedValue = if builtins.isAttrs value then mkVencordCfgInner name value else value;
      in
      nameValuePair (normalizeName context name value) normalizedValue
    ) cfg;

  mkVencordCfg = mkVencordCfgInner "";

  mkFinalPackages =
    {
      cfg,
      vencord,
      equicord,
    }:
    {
      discord = cfg.discord.package.override {
        withVencord = cfg.discord.vencord.enable;
        withEquicord = cfg.discord.equicord.enable;
        withOpenASAR = cfg.discord.openASAR.enable;
        enableAutoscroll = cfg.discord.autoscroll.enable;
        branch = cfg.discord.branch;
        vencord = if cfg.discord.vencord.enable then vencord else null;
        equicord = if cfg.discord.equicord.enable then equicord else null;
      };

      vesktop = cfg.vesktop.package.override {
        withSystemVencord = cfg.vesktop.useSystemVencord;
        withMiddleClickScroll = cfg.vesktop.autoscroll.enable;
        inherit vencord;
      };

      equibop =
        if cfg.equibop.package != null then
          (cfg.equibop.package.override {
            electron = electron_40;
            withMiddleClickScroll = cfg.equibop.autoscroll.enable;
          }).overrideAttrs
            (old: {
              postFixup = (old.postFixup or "") + ''
                wrapProgram $out/bin/equibop \
                  --prefix LD_LIBRARY_PATH : "${
                    lib.makeLibraryPath [
                      libva
                      stdenv.cc.cc.lib
                    ]
                  }"
              '';
            })
        else
          null;

      dorion = cfg.dorion.package;
    };
in
{
  inherit mkVencordCfg mkFinalPackages;
}
