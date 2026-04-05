{ lib, ... }:
{
  imports = [
    (lib.mkRenamedOptionModule
      [ "programs" "nixcord" "package" ]
      [ "programs" "nixcord" "discord" "package" ]
    )
    (lib.mkRenamedOptionModule
      [ "programs" "nixcord" "vesktopPackage" ]
      [ "programs" "nixcord" "vesktop" "package" ]
    )
    (lib.mkRenamedOptionModule
      [ "programs" "nixcord" "vesktopConfigDir" ]
      [ "programs" "nixcord" "vesktop" "configDir" ]
    )
    (lib.mkRenamedOptionModule
      [ "programs" "nixcord" "openASAR" "enable" ]
      [ "programs" "nixcord" "discord" "openASAR" "enable" ]
    )
  ];
}
