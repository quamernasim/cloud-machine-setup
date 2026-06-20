#!/bin/bash

set -e

echo "Installing Antigravity CLI..."
curl -fsSL https://antigravity.google/cli/install.sh | bash

echo
echo "Installation complete."
echo "Version:"
agy --version