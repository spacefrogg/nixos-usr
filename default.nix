{ pkgs ? import <nixpkgs> {} }:

with pkgs;

(import ./release.nix {}).build.${builtins.currentSystem}
