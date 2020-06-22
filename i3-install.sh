#!/bin/bash

dependencies=(git i3lock libxcb-shape0-dev libxml2-dev libcairo2-dev libxcb1-dev libxcb-keysyms1-dev libpango1.0-dev libxcb-util0-dev libxcb-icccm4-dev libyajl-dev libstartup-notification0-dev libxcb-randr0-dev libev-dev libxcb-cursor-dev libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev autoconf xutils-dev libtool automake libxcb-xrm-dev)

echo "Installing i3-gaps dependencies"
apt install -f -y -qq ${dependencies[@]}

mkdir tmp
cd tmp
git clone https://www.github.com/Airblader/i3 i3-gaps
cd i3-gaps
git checkout gaps && git pull
autoreconf --force --install
rm -rf build
mkdir build
cd build
../configure --prefix=/usr --sysconfdir=/etc --disable-sanitizers
make
sudo make install
rm -rf build
i3_lock_dependencies=(pkg-config libpam0g-dev libcairo2-dev libfontconfig1-dev libxcb-composite0-dev libev-dev libx11-xcb-dev libxcb-xkb-dev libxcb-xinerama0-dev libxcb-randr0-dev libxcb-image0-dev libxcb-util-dev libxcb-xrm-dev libxkbcommon-dev libxkbcommon-x11-dev libjpeg-dev)

echo "Installing i3-lock-color-dependencies"
apt install -f -y -qq ${i3_lock_dependencies[@]}

git clone https://github.com/Raymo111/i3lock-color

cd i3lock-color
autoreconf -fiv

rm -rf build/
mkdir -p build && cd build/

../configure --prefix=/usr --sysconfdir=/etc --disable-sanitizers

make
rm -rf build
cd ../
rm -rf i3lock-color
