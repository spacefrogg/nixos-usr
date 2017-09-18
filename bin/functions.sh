# Exit with error message
fatal() {
    local FSTR="$1"
    shift
    local ARGS="$@"
    [ -n "$FSTR" ] && { printf "$FSTR\n" $ARGS ; }
    exit 1
}

# Partially 'apply' arguments to quotation by feeding arguments to stdin of
# current quotation and quote anew.
partial() {
    local quotation="$1"
    local old_quotation="$2"
    shift 2
    eval "$quotation" <<<"{ $old_quotation <<<\"$@ \$(</dev/stdin)\" ; }"
}

# Wrap a simple command to accept input from stdin as command-line arguments
# Example: "$(quote 'printf "Something %s: %s\n"')"
quote() {
    case "${1:1}" in
        '('|'{'|'$') echo "$@" ;;
        *) echo "{ xargs $@ </dev/stdin ; }" ;;
    esac
}

# Call DBus to return the list of loaded units
# Returns list of units on file descriptor 5
read_dbus() {
    local cmd=$1
    shift
    local args="$@"
    local F=$(mktemp)
    exec 5<> "$F"
    busctl --user call org.freedesktop.systemd1 /org/freedesktop/systemd1 org.freedesktop.systemd1.Manager $cmd $args >"$F"
    rm -f "$F"
}

# Read one token
# TYPE - one of s, o, u, i, b to read string, path, and (unsigned) int, Boolean types
#        h to read the message header (type not part of systemd dbus spec)
# QUOTATION - called on reply
# Returns output in variable TOK
#
# Backslash in the input is treated specially and masks delimiters.
read_tok() {
    local TYPE="$1"
    local quotation="$2"
    local TOK
    case "$TYPE" in
        a'('*')')
            local TYPELIST="${TYPE:2:-1}"
            local LEN
            read_tok u "read LEN"
            TOK="$TYPELIST $LEN"
            ;;
        a'{'*'}')
            fatal "Not implemented"
            ;;
        a*)
            local TYPELIST="${TYPELIST:1}"
            local LEN
            read_tok u "$(reply LEN)"
            TOK="$TYPELIST $LEN"
            ;;
        h|u|i|b)
            read -u 5 -d \  TOK
            ;;
        s|o)
            read -u 5 -d \" TOK # read until first quote; garbage
            read -u 5 -d \" TOK # actual content w/o quotes
            ;;
    esac
#    set -x
    eval "$quotation" <<<"$TOK"
#    set +x
}


# Read a DBus reply
# TYPE - expected type, accept any reply type if empty
# QUOTATION - execute QUOTATION with reply given in ARGS array; QUOTATION is
#             called on each element if TYPE is an array type.
# Supported types:
# s - string
# o - object path (string)
# u - unsigned int
# i - int
# b - Boolean
# t - timestamp in microseconds
# d - decimal (float)
# (tuv) - struct elements of types t, u, v
# at n - array of length n; elements with type(s) t
# a{t} n - dictionary with n entries of type t (not implemented, yet)
read_msg() {
    local type=$1
    local quotation="$2"
    local r

    read_tok h 'read r'
    if [ -z "$r" ]; then
        fatal "Error reading DBus reply"
    elif [ -n "$type" -a "$r" != "$type" ]; then
        fatal "Error: Unexpected type '%s' expected type '%s', while reading DBus reply" "$r" "$type"
    fi

    case "$r" in
        a'('*')')
            local typelist len n m
            read_tok "$r" 'read typelist len'
            for ((n=0; n<len; n=n+1)); do
                for ((m=0; m<${#typelist}; m=m+1)); do
                    local typevar="${typelist:$m:1}"
                    local q
                    partial "read -d$'\a' q" "$quotation" $m "$typevar"
                    read_tok $typevar "$q" #"$(partial "$quotation" $m $typevar)"
                done
            done
            ;;
        a'{'*'}')
            fatal "Not implemented"
            ;;
        *)
            read_tok "$r" "$quotation"
    esac
}
