{ config, lib, systemConfiguration, ... }:

with lib;

{

  options = {
    usrEnv = {
      version = mkOption {
        readOnly = true;
        type = types.str;
        default = builtins.readFile ../../../.version;
        description = "Nixos-usr version";
      };
      systemConfig = mkOption {
        internal = true;
        description = ''
          Internal option holding the complete system configuration. Mainly used for
          convenience, e.g. to retrieve the user's home directory as defined there.
        '';
      };
      user = mkOption {
        type = types.str;
        example = "nobody";
        default = import <nixpkgs/nixos/lib/from-env.nix> "USER" "nobody";
        description = ''
          User this configuration will be built for. Defaults to the value of the
          <literal>USER</literal> environment variable or <literal>nobody</literal>if it is
          unset.
        '';
      };
      homeDir = mkOption {
        type = types.str;
        example = "nobody";
        default = import <nixpkgs/nixos/lib/from-env.nix> "HOME"
                         "${config.usrEnv.systemConfig.users.users.${config.usrEnv.user}.home}";
        description = ''
          Home directory where this configuration should be installed into. Defaults to the value
          of the <literal>HOME</literal> environment variable or, if it is unset, to the value of
          the home directory set in the system configuration for the user named in
          <literal>usrEnv.user</literal>.
        '';
      };
    };
  };

  # Include assertions that avoid that user and homeDir end up empty.
  config = {
    usrEnv.systemConfig = ((import <nixpkgs/nixos>) { configuration = systemConfiguration;
                                                      inherit (config.nixpkgs) system; }).config;
  };
}
