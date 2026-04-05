{ pkgs }:

let
  testLib = import ./lib.nix { inherit pkgs; };
  inherit (testLib) firstSharedPlugin;

  evaluatedConfig = testLib.evalHM {
    enable = true;
    config.plugins.${firstSharedPlugin}.enable = true;
  };
in

pkgs.runCommand "hm-eval-test"
  {
    passAsFile = [ "configJson" ];
    configJson = testLib.serializeEvalConfig evaluatedConfig;
  }
  ''
    echo "Home Manager module evaluation successful"
    echo "Config size: $(wc -c < $configJsonPath) bytes"
    touch $out
  ''
