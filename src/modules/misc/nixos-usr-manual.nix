{ config, options, pkgs, lib, ... }:

with lib;

let

  manual = import ../../../doc {
    inherit pkgs config;
    version = config.usrEnv.version;
  };

in {
  config = {
    usrEnv.build.manual = manual;
  };
}
