#!/bin/bash
set -euo pipefail

# Run commands with sudo when not running as root.
sudo() {
    [[ $EUID = 0 ]] || set -- command sudo "$@"
    eval "$@"
}

# Install Bazel.
sudo npm install -g @bazel/bazelisk

# Install Docsify.
sudo npm install -g docsify-cli

# Install Wager.
ssh-keyscan -H github.com >> ~/.ssh/known_hosts
git clone git@github.com:wager/wager.git ~/wager
(cd ~/wager && bazel build //wager/analyze)

cat >> ~/.bashrc << \EOF
wager() {
    local -r root="$HOME/wager"
    local -r workspace="wager/$1"
    local -r arguments="${@:2}"

    if [ ! -d "$root/$workspace" ]; then
        echo "$root/$workspace does not exist."
        return 1
    elif ! grep -q 'wager_workspace' "$root/$workspace/BUILD"; then
        echo "$root/$workspace is not a wager_workspace."
        return 1
    elif ! (cd "$root" && bazel build "//$workspace:app" > /dev/null 2>&1); then
        echo "Build failed. Run cd $root && bazel build //$workspace:app for details."
        return 1
    else
        (cd "$root/$workspace" && eval "$root/bazel-bin/$workspace/app" "$arguments")
        return $?
    fi
}

_complete_wager() {
    if [ $COMP_CWORD -eq 1 ]; then
        COMPREPLY=(`cd ~/wager/wager && find * -name 'BUILD' -exec grep -qi 'wager_workspace' {} ';' -printf '%h ' | sort -u`)
    elif [ $COMP_CWORD -eq 2 ]; then
        COMPREPLY=($(compgen -W 'backfill compute describe notebook shell' -- ${COMP_WORDS[COMP_CWORD]}))
    else
        COMPREPLY=()
    fi
}

complete -F _complete_wager wager
EOF