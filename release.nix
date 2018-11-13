{ nixosUsr ? { outPath = ./.; revCount = 12345; shortRev = "abcdef"; }
, nixpkgsSrc ? <nixpkgs>
, supportedSystems ? [ "x86_64-linux" "i686-linux" ]
}:

with import "${nixpkgsSrc}/lib";

let
  pkgs = import nixpkgsSrc { system = "x86_64-linux"; };
  version = fileContents ./.version;

  forAllSystems = genAttrs supportedSystems;

  buildFromConfig = userConfiguration: sel: forAllSystems (system: (sel (import ./src {
    inherit system userConfiguration;
  }).config));

in rec {
  manpages = buildFromConfig ({ pkgs, ... }: { }) (config: config.usrEnv.build.manual.manpages);
  build = forAllSystems (system: 
    with import nixpkgsSrc { inherit system; };
    pkgs.stdenvNoCC.mkDerivation {
      name = "nixos-usr-${version}";
      inherit version;

      preferLocalBuild = true;
      allowSubstitutes = false;

      buildCommand = ''
        mkdir -p $out/bin $out/share/man/man8 $out/nixos-usr
        substitute ${./bin/nixos-usr.sh} $out/bin/nixos-usr --subst-var shell --subst-var nixBuild --subst-var manual \
          --subst-var out
        chmod +x $out/bin/nixos-usr
        cp $manual $out/share/man/man8
        cp -r ${./src}/* $out/nixos-usr #*/
      '';

      shell = "${pkgs.stdenvNoCC.shell}";
      nixBuild = "${pkgs.nix}/bin/nix-build";
      manual = "${manpages.${system}}/share/man/man8/nixos-usr.8";
    });
}
