#!/bin/bash

# Remove k3s
/usr/local/bin/k3s-uninstall.sh

# Remove AWX directories
sudo rm -rf /data/postgres-13
sudo rm -rf /data/projects

# Remove cloned repository
sudo rm -rf ~/guide-k3s-awx-tower

# Clean up dependencies 
sudo apt-get remove -y git curl ansible-core build-essential
sudo apt-get autoremove -y
sudo apt-get clean

echo "K3s and AWX components have been removed."
