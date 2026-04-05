{ lib, pkgs, ... }:
let
  inherit (lib) mkEnableOption mkOption types;
in
{
  options.programs.nixcord.dorion = {
    enable = mkEnableOption ''
      Whether to enable Dorion
    '';
    installPackage = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to add `cfg.finalPackage.dorion` to `home.packages`.";
    };
    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../pkgs/dorion.nix { };
      description = ''
        The Dorion package to use
      '';
    };
    configDir = mkOption {
      type = types.path;
      description = "Config path for Dorion";
    };
    theme = mkOption {
      type = types.str;
      default = "none";
      description = "Theme to use in Dorion";
    };
    themes = mkOption {
      type = types.listOf types.str;
      default = [ "none" ];
      description = "List of available themes";
    };
    zoom = mkOption {
      type = types.str;
      default = "1.0";
      description = "Zoom level for the client";
    };
    blur = mkOption {
      type = types.enum [
        "none"
        "blur"
        "acrylic"
      ];
      default = "none";
      description = "Window blur effect type";
    };
    blurCss = mkOption {
      type = types.bool;
      default = true;
      description = "Enable CSS blur effects";
    };
    useNativeTitlebar = mkOption {
      type = types.bool;
      default = false;
      description = "Use native window titlebar";
    };
    startMaximized = mkOption {
      type = types.bool;
      default = false;
      description = "Start Dorion maximized";
    };
    disableHardwareAccel = mkOption {
      type = types.bool;
      default = false;
      description = "Disable hardware acceleration";
    };
    sysTray = mkOption {
      type = types.bool;
      default = false;
      description = "Enable system tray integration";
    };
    trayIconEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable tray icon";
    };
    openOnStartup = mkOption {
      type = types.bool;
      default = false;
      description = "Open Dorion on system startup";
    };
    startupMinimized = mkOption {
      type = types.bool;
      default = false;
      description = "Start minimized to tray";
    };
    multiInstance = mkOption {
      type = types.bool;
      default = false;
      description = "Allow multiple Dorion instances";
    };
    pushToTalk = mkOption {
      type = types.bool;
      default = false;
      description = "Enable push-to-talk";
    };
    pushToTalkKeys = mkOption {
      type = types.listOf types.str;
      default = [ "RControl" ];
      description = "Keys for push-to-talk activation";
    };
    updateNotify = mkOption {
      type = types.bool;
      default = true;
      description = "Show update notifications";
    };
    desktopNotifications = mkOption {
      type = types.bool;
      default = false;
      description = "Enable desktop notifications";
    };
    unreadBadge = mkOption {
      type = types.bool;
      default = true;
      description = "Show unread message badge";
    };
    win7StyleNotifications = mkOption {
      type = types.bool;
      default = false;
      description = "Use Windows 7 style notifications";
    };
    cacheCss = mkOption {
      type = types.bool;
      default = false;
      description = "Cache CSS for faster loading";
    };
    autoClearCache = mkOption {
      type = types.bool;
      default = false;
      description = "Automatically clear cache on startup";
    };
    clientType = mkOption {
      type = types.str;
      default = "default";
      description = "Discord client type to emulate";
    };
    clientMods = mkOption {
      type = types.listOf types.str;
      default = [
        "Shelter"
        "Vencord"
      ];
      description = "Client modifications to enable";
    };
    clientPlugins = mkOption {
      type = types.bool;
      default = true;
      description = "Enable client plugins";
    };
    profile = mkOption {
      type = types.str;
      default = "default";
      description = "Profile name to use";
    };
    streamerModeDetection = mkOption {
      type = types.bool;
      default = false;
      description = "Enable streamer mode detection";
    };
    rpcServer = mkOption {
      type = types.bool;
      default = false;
      description = "Enable RPC server";
    };
    rpcProcessScanner = mkOption {
      type = types.bool;
      default = true;
      description = "Enable RPC process scanner";
    };
    rpcIpcConnector = mkOption {
      type = types.bool;
      default = true;
      description = "Enable RPC IPC connector";
    };
    rpcWebsocketConnector = mkOption {
      type = types.bool;
      default = true;
      description = "Enable RPC WebSocket connector";
    };
    rpcSecondaryEvents = mkOption {
      type = types.bool;
      default = true;
      description = "Enable RPC secondary events";
    };
    proxyUri = mkOption {
      type = types.str;
      default = "";
      description = "Proxy URI to use for connections";
    };
    keybinds = mkOption {
      type = types.attrs;
      default = { };
      description = "Custom keybind mappings";
    };
    keybindsEnabled = mkOption {
      type = types.bool;
      default = true;
      description = "Enable custom keybinds";
    };
    extraSettings = mkOption {
      type = types.attrs;
      default = { };
      description = ''
        Additional settings to merge into config.json.
        These will override any conflicting auto-generated settings.
      '';
    };
  };
}
