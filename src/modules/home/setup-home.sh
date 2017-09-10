[ $# -eq 3 ] || exit 1
home="$1"
target="$2"
user="$3"

# Keep track of copied files to be able to clean them up
if [ -f "$target/.tree" ]; then
    readarray -d $'\0' oldTree <"$target"/.tree 
else
    declare -A oldTree
fi
exec 3>"$target"/.tree

# Newly created files, copied or symlinked
declare -A created

# S - warning to print
warn() {
    printf "warning: %s\n" "$1"
}

# SRC - absolute file name to be symlinked
# DST - absolute file name of target
symlink() {
    local src="$1"
    local dst="$2"

    if [ ! -L "$dst" -a -d "$dst" ]; then
        shopt -s nullglob
        shopt -s dotglob
        local fns=("${dst}"/*)
        # Array contains zero elements if $dst is empty
        (( ${#fns[*]} )) && {
            warn "Target ‘$dst’ is a non-empty directory, refusing to replace with symlink"
            shopt -u nullglob
            shopt -u dotglob
            return;
        }
        rmdir "$dst"
    fi
    ln -Tsf "$src" "$dst"
    shopt -u nullglob
    shopt -u dotglob
}

# FN - absolute file name to be symlinked/copied
setlink() {
    local fn="${1##${home}/}"
    [ -z "$fn" ] && return
    local target_="$target/$fn"

    mkdir -p $(dirname "$target_")
    created[$fn]=1

    local mode=$(cat "$1.mode" 2>/dev/null)
    local gid=$(cat "$1.gid" 2>/dev/null)

    if [ "$mode" = "direct-symlink" ]; then
        symlink "$(readlink -f "$1")" "$target_"
    elif [ -n "$mode" ]; then
        install -T -m "$mode" -o "$user"${gid:+ -g "$gid"} "$1" "$target_" || {
            warn "Could not copy from '$1' to $target_"
        }
    else
        symlink "$1" "$target_"
    fi
    printf "%s\0" "$fn" 1>&3 # $target/.tree
}

# Temp file needed to avoid sub-shell and \0 not allowed in command substitution
find "$home" -type l -print0 >"$target/.flist"

# Cleanup old links
readarray -d $'\0' tmpTree <"$target/.flist"
declare -A newTree
for i in "${tmpTree[@]}" ; do
    newTree+=(["${i##${home}/}"]=1)
done
export newTree

# Prune the target tree of stale symlinks, might make directories empty that
# are going to be replaced by symlinks.
for i in "${oldTree[@]}" ; do
    if [ -L "$target/$i" -a \( -z "${newTree["$i"]}" -o -d "$home/$i" \) ]; then
        unlink "$target/$i"
    fi
done

while read -d $'\0' f; do
    setlink "$f"
done <"$target/.flist"
rm "$target/.flist"

# Delete files that were copied in a previous version but are now gone.
for i in "${oldTree[@]}" ; do
    if [ -z "${created[$i]}" ]; then
        fn="$target/$i"
        if [ ! -d "$fn" -a -e "$fn" ]; then
            printf "removing obsolete file ‘%s’...\n" "$fn" 1>&2
            unlink "$fn"
        fi
    fi
done

# Close $target/.tree
3>&-
