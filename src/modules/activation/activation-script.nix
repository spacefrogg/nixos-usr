{ config, lib, pkgs, ... }@args:

with lib;

let
  activationScrSet = (import <nixpkgs/nixos/modules/system/activation/activation-script.nix> args);

  addAttributeName = mapAttrs (a: v: v // {
    text = ''
      ${v.text}
    '';
  });

  path = with pkgs; map getBin
    [ coreutils
      gnugrep
      findutils
      acl
      # glibc # needed for getent
      # shadow # needed for shady stuff...
      # nettools # needed for hostname
      # utillinux # needed for mount and mountpoint
    ];
in {

  options = {
    usrEnv.activationScripts = activationScrSet.options.system.activationScripts // {
      apply = set: {
        script = ''
          #! ${pkgs.stdenvNoCC.shell}
          
          usrEnvConfig=@out@
          
          export PATH=/empty
          for i in ${toString path}; do
              PATH=$PATH:$i/bin:$i/sbin
          done
          
          _status=0
          trap "_status=1" ERR
          
          umask 022

          _intendedUser=${lib.escapeShellArg config.usrEnv.user}

          [ "$USER" = "$_intendedUser" ] || {
            printf "This configuration is not applicable to your user! Aborting...\n" 1>&2
            exit 2
          }
          
          ${
            let
              set' = mapAttrs (n: v: if isString v then noDepEntry v else v) set;
              withHeadlines = addAttributeName set';
            in textClosureMap id (withHeadlines) (attrNames withHeadlines)
          }
          
          ln -sfn $usrEnvConfig /nix/var/nix/gcroots/per-user/$_intendedUser/current-usr
          exit $_status
        '';
      };
    };
  };

  config = {
    usrEnv.activationScripts.base = ''
      # Base case to keep the combinator happy
    '';
  };
}
