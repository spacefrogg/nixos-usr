#!@shell@

set -e

usage() {
    exec man @manual@
}

mandatory_arg() {
    [ -n "$1" ] || { printf "Option %s needs an argument" "$2"; exit 1; }
}

args=("$@")
action=
profile_prefix=/nix/var/nix/profiles/per-user/${USER}/
profile_name=nixos-usr
declare -a extraBuildFlags

if [ -z "$(echo "$NIX_PATH" | grep -e '\(^\|.:\)nixos-usr=' -)" ]; then
    NIX_PATH=$NIX_PATH:nixos-usr=@out@/nixos-usr
fi

while [ "$#" -gt 0 ]; do
    opt="$1"; shift
    case "$opt" in
        --help)
            usage ;;
        --profile-name|-p)
            mandatory_arg "$1" "$opt"
            profile_name="$1"
            ;;
        dry-build)
            extraBuildFlags+=(--dry-run) ;&
        switch|test|build|dry-activate)
            [ -n "$action" ] && { 
                printf "Only one action can be executed. \`%s' already given." "$action"; exit 1;
            }
            action="$opt"
            ;;
        *)
            extraBuildFlags+=("$opt") ;;
    esac
done

[ -n "$action" ] || usage

profile="$profile_prefix$profile_name"

printf "building user configuration...\n" >&2
case "$action" in

    test|dry-activate)
        run_switch=1 ;&
    build|dry-build)
        pathToConfig="$(@nixBuild@ '<nixos-usr>' --no-out-link -A usrEnv "${extraBuildFlags[@]}")"
        ;;

    switch)
        pathToConfig="$(@nixBuild@ '<nixos-usr>' -k -A usrEnv "${extraBuildFlags[@]}")"
        nix-env -p "$profile" --set "$pathToConfig"
        run_switch=1
        ;;
esac

if [ -n "$run_switch" ]; then
    if ! $pathToConfig/bin/switch-to-configuration "$action"; then
        echo "warning: error(s) occurred switching to the new user configuration" >&2
        exit 1
    fi
fi
