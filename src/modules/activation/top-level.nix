{ config, lib, pkgs, ... }:

with lib;


let
  usrEnvBuilder = ''
    mkdir $out

    echo "$activationScript" > $out/activate
    substituteInPlace $out/activate --subst-var out
    chmod u+x $out/activate
    unset activationScript

    ln -s ${lib.escapeShellArg config.usrEnv.build.home}/home $out/home

    echo -n "$system" > $out/system

    mkdir $out/bin
    substituteAll ${./switch-to-configuration.sh} $out/bin/switch-to-configuration
    chmod +x $out/bin/switch-to-configuration

    ${config.usrEnv.extraEnvBuilderCmds}
  '';

  failed = map (x: x.message) (filter (x: !x.assertion) config.assertions);

  showWarnings = res: fold (w: x: builtins.trace "[1;31mwarning: ${w}[0m" x) res config.warnings;

  usrEnv = showWarnings (
    if failed == [] then pkgs.stdenvNoCC.mkDerivation {
      name = "nixos-usr-${config.usrEnv.user}";
      preferLocalBuild = true;
      allowSubstitutes = false;
      buildCommand = usrEnvBuilder;

      inherit (pkgs) utillinux coreutils;
      activationScript = config.usrEnv.activationScripts.script;

      perl = "${pkgs.perl}/bin/perl -I${pkgs.perlPackages.FileSlurp}/lib/perl5/site_perl";
      shell = "${pkgs.stdenvNoCC.shell}";
  } else throw "\nFailed assertions:\n${concatStringsSep "\n" (map (x: "- ${x}") failed)}");

  ## For documentation purposes:
  # The NixOS system builder in modules/system/top-level.nix has an extra step, here,
  # that replaces runtime dependencies given in config.system.replaceRuntimeDependencies.
  # Left out for now for simplicity reasons.

in {
  options = {
    usrEnv = {
      build = mkOption {
        internal = true;
        default = {};
        description = ''
          Attribute set of derivations used to setup the user environment.
        '';
      };

      extraEnvBuilderCmds = mkOption {
        type = types.lines;
        internal = true;
        default = "";
        description = ''
          Code to be added to the builder creating the user environment store path.
        '';
      };
    };
  };

  config = {
    usrEnv.build.toplevel = usrEnv;
  };
}
