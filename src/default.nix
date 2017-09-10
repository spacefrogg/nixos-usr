{ configuration ? import <nixpkgs/nixos/lib/from-env.nix> "NIXOS_CONFIG" <nixos-config>
, userConfiguration ? import <nixpkgs/nixos/lib/from-env.nix> "NIXOS_USR_CONFIG" <nixos-usr-config>
, system ? builtins.currentSystem
}:

let
  eval = import <nixpkgs/nixos/lib/eval-config.nix> {
    inherit system;
    baseModules = (import ./modules/module-list.nix)
                  # Some standard NixOS modules we need
                  ++ [ <nixpkgs/nixos/modules/misc/nixpkgs.nix>
                       <nixpkgs/nixos/modules/misc/assertions.nix>
                       rec { _file = ./default.nix;
                         key = _file;
                         config = {
                           _module.args.systemConfiguration = configuration;
                         };
                       }
                     ];
    modules = [ userConfiguration ];
    specialArgs = { modulesPath = ./modules; };
  };

in {
  inherit (eval) config options;
  
  usrEnv = eval.config.usrEnv.build.toplevel;
}
