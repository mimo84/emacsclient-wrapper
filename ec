#!/usr/bin/env bash

set -eu

scriptVersion=0.0.2

# function definitions
showUsageMessage() {
    set +x >/dev/null
    exitStatus=$1

    cat << HELP_USAGE
    Usage: ec [option] [emacsclient-options]

    Run the emacsclient and if not already running starts the emacs server.

    Other than the options from the script, the options from emacsclient can be passed through.
    See: https://www.gnu.org/software/emacs/manual/html_node/emacs/emacsclient-Options.html

    Options:
      -k, --kill      finds the processes with emacs --fd-server options and kills them

      -p, --profile   available: $( tail -n +2 ~/.emacs-profiles.el | head -n -1 | cut -d "\"" -f 2 | tr '\n' ' ')

      -i, --init-directory uses the init-directory to start the deamon rather than the chemasc option
                           note that the two options are mutually exclusive, with profile having precedence

      -l, --list      lists the socket files that can be used to connect to a different server

      -h, --help      shows this usage message then exits

      -v, --version   shows the script version number then exits
HELP_USAGE
    exit ${exitStatus}
}

runEmacsClient() {
    if [[ $client_args =~ (^|[[:space:]])-nw($|[[:space:]]) ]]; then
      echo "Opening emacs in terminal mode"
      $emacsclient $client_args -a ''
    else
      echo "opening emacsclient in gui mode with $client_args"
      $emacsclient -c $client_args -a '' &
    fi
}

showVersion() {
    echo "$(basename $0) scriptVersion: ${scriptVersion} "
}

showVersionAndExit() {
    showVersion
    exit 0
}

# Ensure required dependencies are available in the system
if ! command -v brew >/dev/null 2>&1; then
    echo "brew command not found. Please install Homebrew first."
    exit 1
fi

if ! command -v lsof >/dev/null 2>&1; then
    echo "lsof command not found. Please install it first."
    exit 1
fi

# check if a socket file named server is already present
socket_file=$(ls "${TMPDIR-/tmp}/emacs$(id -u)" | grep server || true)

# emacs locations
emacs=$(brew --prefix)/opt/emacs-plus/bin/emacs
emacsclient=$(brew --prefix)/opt/emacs-plus/bin/emacsclient


# parse script arguments
client_args=""
kill=false
list=false
profile=default

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            showUsageMessage 0
            ;;
        -v|--version)
            showVersionAndExit
            ;;
        -k|--kill)
            kill=true
            shift
            ;;
        -p|--profile)
            profile=$2
            shift
            shift
            ;;
        -i|--init-directory)
            init_directory=$2
            profile=""
            shift
            shift
            ;;
        -l|--list)
            list=true
            shift
            ;;
        *)
            client_args+="$1 "
            shift
            ;;
    esac
done


if [ "$kill" = true ]; then
    $emacsclient $client_args --eval "(kill-emacs)"
    exit 0
fi

if [ "$list" = true ]; then
    echo $(lsof -c Emacs | grep "emacs$(id -u)" | tr -s " " | cut -d' ' -f8 | xargs -n 1 basename)
    exit 0
fi

if [[ -z "$socket_file" ]]; then
    if [[ -z "$profile" ]]; then
        if [[ "$init_directory" = ""  ]]; then
            runEmacsClient
        else
            echo "Starting emacs server with init-directory set to $init_directory"
            $emacs --bg-daemon --init-directory $init_directory
        fi
    else
      echo "Starting emacs server with profile $profile"
      $emacs --bg-daemon --with-profile $profile
    fi
fi

runEmacsClient
