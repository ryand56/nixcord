{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.programs.nixcord.dorion = {
    enable = mkEnableOption "Dorion";
    installPackage = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to install the final Dorion package.";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.callPackage "${
        pkgs.fetchFromGitHub {
          owner = "FlameFlag";
          repo = "nixpkgs";
          rev = "687fe3c6346172edb78fa0116860c4af1109b5fc";
          hash = "sha256-D4rM3zHNe94aZW0w7jC5TP+A1OFdcW9DbXzNdrerpg4=";
        }
      }/pkgs/by-name/do/dorion/package.nix" { };
      defaultText = lib.literalMD "custom Dorion package from FlameFlag/nixpkgs";
      description = "The Dorion package to use.";
    };
    configDir = mkOption {
      type = types.path;
      description = "Config directory for Dorion.";
    };
    theme = mkOption {
      type = types.str;
      default = "none";
      description = "Theme to use in Dorion.";
      example = "ClearVision";
    };
    themes = mkOption {
      type = types.listOf types.str;
      default = [ "none" ];
      description = "List of available themes.";
    };
    zoom = mkOption {
      type = types.str;
      default = "1.0";
      description = "Zoom level for the client.";
      example = "1.25";
    };
    blur = mkOption {
      type = types.enum [
        "none"
        "blur"
        "acrylic"
      ];
      default = "none";
      description = "Window blur effect type.";
    };
    blurCss = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable CSS blur effects.";
    };
    useNativeTitlebar = mkEnableOption "native window titlebar";
    startMaximized = mkEnableOption "starting Dorion maximized";
    disableHardwareAccel = mkEnableOption "disabling hardware acceleration";
    sysTray = mkEnableOption "system tray integration";
    trayIconEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to show the tray icon.";
    };
    openOnStartup = mkEnableOption "opening Dorion on system startup";
    startupMinimized = mkEnableOption "starting minimized to tray";
    multiInstance = mkEnableOption "multiple Dorion instances";
    pushToTalk = mkEnableOption "push-to-talk";
    pushToTalkKeys = mkOption {
      type = types.listOf types.str;
      default = [ "RControl" ];
      description = "Keys for push-to-talk activation.";
      example = [
        "RControl"
        "F1"
      ];
    };
    updateNotify = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to show update notifications.";
    };
    desktopNotifications = mkEnableOption "desktop notifications";
    unreadBadge = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to show the unread message badge.";
    };
    win7StyleNotifications = mkEnableOption "Windows 7 style notifications";
    cacheCss = mkEnableOption "CSS caching for faster loading";
    autoClearCache = mkEnableOption "automatic cache clearing on startup";
    clientType = mkOption {
      type = types.str;
      default = "default";
      description = "Discord client type to emulate.";
    };
    clientMods = mkOption {
      type = types.listOf types.str;
      default = [
        "Shelter"
        "Vencord"
      ];
      description = "Client modifications to enable.";
    };
    clientPlugins = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable client plugins.";
    };
    profile = mkOption {
      type = types.str;
      default = "default";
      description = "Profile name to use.";
    };
    streamerModeDetection = mkEnableOption "streamer mode detection";
    rpcServer = mkEnableOption "RPC server";
    rpcProcessScanner = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable the RPC process scanner.";
    };
    rpcIpcConnector = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable the RPC IPC connector.";
    };
    rpcWebsocketConnector = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable the RPC WebSocket connector.";
    };
    rpcSecondaryEvents = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable RPC secondary events.";
    };
    proxyUri = mkOption {
      type = types.str;
      default = "";
      description = "Proxy URI to use for connections.";
      example = "socks5://127.0.0.1:1080";
    };
    keybinds = mkOption {
      type = types.attrsOf types.anything;
      default = { };
      description = "Custom keybind mappings.";
    };
    keybindsEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to enable custom keybinds.";
    };
    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = "Additional settings to merge into config.json. These override any conflicting auto-generated settings.";
    };
  };
}
