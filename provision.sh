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
    neofetch
    blueman
    feh
    compton
    dunst
)

snap_packages=()

snap_classic_packages=(
    code
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

## TODO ONLY DOWNLAD IF IT ISNT INSTALLED.
echo "Downlading google-chrome"
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb

echo "Installing google-chrome"
apt install ./google-chrome-stable_current_amd64.deb
rm ./google-chrome-stable_current_amd64.deb

echo "Installing i3-gaps"
./i3-install.sh
echo "Installing polybar"
./polybar-install.sh

echo "Stowing config to .config"
stow config

echo "Stowing Xresources"
stow X

echo "Moving resize-font-script to .urxvt/ext"
mkdir -p ~/.urxvt/ext
mv X/scripts/resize-font ~/.urxvt/ext/

echo "Stowing rofi"
stow rofi

echo "Stowing git"
stow git

echo "Stowing fonts"
stow fonts

echo "Copying background.jpg to Pictures-folder"
cp background.jpg ~/Pictures/background.jpg

echo "Installing oh-my-zsh"
sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" &!

echo "Installing oh-my-zsh-plugins"
sleep 10
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

echo "Stowing zsh"
rm ~/.zshrc
stow zsh

## TODO SET DEFAULT SHELL?
