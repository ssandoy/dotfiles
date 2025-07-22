#!/bin/bash

echo "Running provision-script"

if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi

apt_packages=(
    git
    zsh
    rxvt-unicode
    stow
    htop
    curl
    vim
    wget
    neofetch
    feh
    compton
    dunst
    yad
    slack
    tmux
    xclip
    fzf
    bat
)

snap_packages=()

snap_classic_packages=(
    code
    slack
)

echo "Checking for apt updates"
apt update -qq
echo "Installing apt updates"
apt upgrade -y -qq

echo "Installing base-packages"
apt install -f -y -qq ${apt_packages[@]}

echo "Installing snap base-packages"
snap install ${snap_packages[@]}

echo "Installing snap classic base-packages"
snap install ${snap_classic_packages[@]}  --classic

echo "Setting zsh as default shell"
chsh -s $(which zsh)


echo "Running stow-all.sh to symlink configs"
./stow-all.sh

