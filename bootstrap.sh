#!/usr/bin/env bash
echo
echo Bootstraping the installer, hold on...
echo
nix-env -iA nixos.diceware nixos.wget 
wget -q http://raw.githubusercontent.com/mmahut/cdb/master/install.sh -O /etc/nixos/install.sh && chmod +x /etc/nixos/install.sh
bash /etc/nixos/install.sh
