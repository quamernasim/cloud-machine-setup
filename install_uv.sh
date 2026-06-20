#!/bin/bash

set -e

echo "Updating package list..."
sudo apt update

echo "Installing uv..."
curl -LsSf https://astral.sh/uv/install.sh | sh

echo
echo "Installation complete."

# Load uv into current shell if installed in default location
export PATH="$HOME/.local/bin:$PATH"

echo "Installed version:"
uv --version