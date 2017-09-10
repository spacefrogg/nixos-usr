#! @shell@

out="@out@"

action="$1"
shift

case "$action" in 
    switch)
        export _NIXOS_USR_SWITCH=1
        ;&
    test)
        "$out/activate"
        exit $?
        ;;
    dry-activate)
        printf "Nothing implemented, yet\n"
        exit 0
        ;;
    *) cat <<EOF
Usage: $(basename $0) switch | test | dry-activate

switch:         make the configuration the default and activate now
test:           activate the configuration without making it the default
dry-activate:   show what would be done if this configuration were activated
EOF
       exit 1
       ;;
esac
