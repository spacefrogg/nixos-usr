source $stdenv/setup

dir=home
mkdir -p $out/$dir

set -f
sources_=($sources)
targets_=($targets)
modes_=($modes)
gids_=($gids)
set +f

for ((i = 0; i < ${#targets_[@]}; i++)); do
    source="${sources_[$i]}"
    target="${targets_[$i]}"

    if [[ "$source" =~ '*' ]]; then

        # If the source name contains '*', perform globbing.
        mkdir -p $out/$dir/$target
        for fn in $source; do
            ln -s "$fn" $out/$dir/$target/
        done

    else
        
        mkdir -p $out/$dir/$(dirname $target)
        if ! [ -e $out/$dir/$target ]; then
            ln -s $source $out/$dir/$target
        else
            echo "duplicate entry $target -> $source"
            if test "$(readlink $out/$dir/$target)" != "$source"; then
                echo "mismatched duplicate entry $(readlink $out/$dir/$target) <-> $source"
                exit 1
            fi
        fi
        
        if test "${modes_[$i]}" != symlink; then
            echo "${modes_[$i]}" > $out/$dir/$target.mode
            echo "${gids_[$i]}" > $out/$dir/$target.gid
        fi

    fi
done
