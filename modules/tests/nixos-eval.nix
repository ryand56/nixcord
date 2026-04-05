{ pkgs }:

let
  testLib = import ./lib.nix { inherit pkgs; };
  inherit (testLib) firstSharedPlugin;

  evaluatedConfig = testLib.evalNixOS {
    enable = true;
    config.plugins.${firstSharedPlugin}.enable = true;
  };
in

pkgs.runCommand "nixos-eval-test"
  {
    passAsFile = [ "configJson" ];
    configJson = testLib.serializeEvalConfig evaluatedConfig;
  }
  ''
    echo "NixOS module evaluation successful"
    echo "Config size: $(wc -c < $configJsonPath) bytes"
    touch $out
  ''
