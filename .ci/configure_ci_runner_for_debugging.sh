#!/bin/bash
# this script is used to install tools for the GitHub Actions CI runner while debugging with ssh

if [[ -z "${GITHUB_ACTIONS}" ]]; then
    echo "Error: This script is intended to run only in GitHub Actions environment"
    exit 1
fi

cat >> $HOME/.bashrc <<'EOF'
function use_kind_kubeconfig() {
    export KUBECONFIG=$(ls $HOME/kind/pulsar-ci-*/kubeconfig.yaml)
}

function kubectl() {
    # use kind environment's kubeconfig
    if [ -z "$KUBECONFIG" ]; then
        use_kind_kubeconfig
    fi
    command kubectl "$@"
}

function k9s() {
    # use kind environment's kubeconfig
    if [ -z "$KUBECONFIG" ]; then
        use_kind_kubeconfig
    fi
    # install k9s on the fly
    if [ ! -x /usr/local/bin/k9s ]; then
        echo "Installing k9s..."
        curl -L -s https://github.com/derailed/k9s/releases/download/v0.32.5/k9s_Linux_amd64.tar.gz | sudo tar xz -C /usr/local/bin k9s
    fi
    command k9s "$@"
}

alias k=kubectl
EOF
cat >> $HOME/.bash_profile <<'EOF'
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
EOF