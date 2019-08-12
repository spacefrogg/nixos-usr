{ configuration ? import <nixpkgs/nixos/lib/from-env.nix> "NIXOS_CONFIG" <nixos-config>
, userConfiguration ? import <nixpkgs/nixos/lib/from-env.nix> "NIXOS_USR_CONFIG" <nixos-usr-config>
, system ? builtins.currentSystem
}:

let
  eval = import <nixpkgs/nixos/lib/eval-config.nix> {
    inherit system;
    modules = [
      configuration
      userConfiguration
    ] ++ (import ./modules/module-list.nix);
  };

in {
  inherit (eval) config options;

  usrEnv = eval.config.usrEnv.build.toplevel;
}
