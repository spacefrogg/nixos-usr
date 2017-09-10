{ config, lib, pkgs, ... }:

with lib;

let

  home' = filter (f: f.enable) (attrValues config.usrEnv.home);

  home = pkgs.stdenvNoCC.mkDerivation {
    name = "home";
    builder = ./make-home.sh;

    preferLocalBuild = true;
    allowSubstitutes = false;

    sources = map (x: x.source) home';
    targets = map (x: x.target) home';
    modes = map (x: x.mode) home';
    gids  = map (x: x.gid) home';
  };

in {
  options = {

    usrEnv.home = mkOption {
      default = {};
      example = literalExample ''
        { "link-to-sensitive-file" = 
            { source = "/string/to/absolute/location";
              # Target gets linked directly to source location
            };
          "copy-of-sensitive-file" =
            { source = "/string/pointing/absolute/location";
              mode = "0440";
              # Source is copied to destination with mode bits set
            };
          "non-sensitive-file"
            { source = /path/to/file/that/becomes/store/path;
              # Target is linked directly to resulting store path. This is the default.
            };
          "non-sensitive-file-2" =
            { source = /path/to/file/that/becomes/store/path;
              mode = "symlink";
              # Target is indirectly linked via the store path of usrEnv.home
            };
          ".tmux.conf".text = "set-prefix ...";
        }
      '';
      description = ''
        Set of files that are linked to the user's home directory.
      '';
      type = with types; loaOf (submodule (
        { name, config, ... }:
        { options = {

            enable = mkOption {
              type = types.bool;
              default = true;
              description = ''
                Whether this file should be generated. This option
                allows specific files to be disabled.
              '';
            };

            target = mkOption {
              type = types.str;
              description = ''
                Name of symlink (relative to home directory). Defaults
                to the attribute name.
              '';
            };

            text = mkOption {
              type = types.nullOr types.lines;
              default = null;
              description = "Text (content) of the file.";
            };

            source = mkOption {
              type = types.path;
              description = ''
                Path of the source file. If provided as a string, the file
                is not copied to the /nix/store, which is useful if it
                contains sensitive data.
              '';
            };

            mode = mkOption {
              type = types.str;
              default = "direct-symlink";
              example = "0600";
              description = ''
                If set to something else than <literal>symlink</literal> or
                <literal>direct-symlink</literal>, the file is copied
                instead of symlinked, with the given file mode.
              '';
            };

            gid = mkOption {
              default = null;
              type = types.nullOr types.int;
              description = ''
                GID of the created file. Only takes effect when the file is
                not copied (its mode is not
                <literal>symlink</literal>). Defaults to
                <literal>null</literal>, which is the user's group.
              '';
            };
          };

          config = {
            target = mkDefault name;
            source = mkIf (config.text != null) (
              let name' = "home-" + baseNameOf name;
              in mkDefault (pkgs.writeText name' config.text));
          };
        }));
    };
  };

  config = {
    usrEnv.build.home = home;
    usrEnv.activationScripts.etc = stringAfter [ "base" ] ''
      # Set up links to home.
      echo "setting up ${lib.escapeShellArg config.usrEnv.homeDir}..."
      ${pkgs.stdenvNoCC.shell} ${./setup-home.sh} ${home}/home ${lib.escapeShellArg config.usrEnv.homeDir} ${lib.escapeShellArg config.usrEnv.user}
    '';
  };
}
