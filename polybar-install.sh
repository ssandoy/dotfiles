#!/bin/bash

echo "Running polybar-install"

dependencies=(
    libcairo2-dev
    libxcb-*-dev
    python
    wget
    libjsoncpp-dev
    cmake
    libpulse-dev
    libiw-dev
    xcb-proto
    python-xcbgen
)

echo "Installing dependencies"

apt install -f -y -qq ${dependencies[@]}

echo "Downlading and extracting polybar"

wget https://github.com/polybar/polybar/releases/download/3.4.2/polybar-3.4.2.tar && tar xvf polybar-3.4.2.tar -C ~/ && rm polybar-3.4.2.tar

cd ~/polybar
mkdir build
cd build
cmake ..
make -j$(nproc)
sudo make install