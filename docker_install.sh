#!/bin/bash

set -e

echo "Updating package list..."
sudo apt-get update

echo "Installing Docker..."
sudo apt install -y docker.io

echo
echo "Docker installed successfully."

echo "Docker version:"
docker --version