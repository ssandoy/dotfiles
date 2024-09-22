#!/bin/bash

echo "Running provision-script"

if [ "$(id -u)" -ne 0 ]; then
        echo 'This script must be run by root' >&2
        exit 1
fi


apt_packages=(
    git
    zsh
    rofi
    rxvt-unicode
    stow
    htop
    curl
    vim
    wget
)

snap_packages=()

snap_classic_packages=()
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


echo "Stowing config to .config"
stow config

echo "Stowing Xresources"
stow X


echo "Installing oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" &!

echo "Installing oh-my-zsh-plugins"
sleep 10
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

echo "Stowing zsh"
rm ~/.zshrc
stow zsh

echo "Setting zsh as default shell"
chsh -s $(which zsh)


