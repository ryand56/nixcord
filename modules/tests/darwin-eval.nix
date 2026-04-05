{ pkgs }:

let
  testLib = import ./lib.nix { inherit pkgs; };
  inherit (testLib) firstSharedPlugin;

  evaluatedConfig = testLib.evalDarwin {
    enable = true;
    config.plugins.${firstSharedPlugin}.enable = true;
  };
in

pkgs.runCommand "darwin-eval-test"
  {
    passAsFile = [ "configJson" ];
    configJson = testLib.serializeEvalConfig evaluatedConfig;
  }
  ''
    echo "Darwin module evaluation successful"
    echo "Config size: $(wc -c < $configJsonPath) bytes"
    touch $out
  ''
