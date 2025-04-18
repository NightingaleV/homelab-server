#!/usr/bin/env bash

set -euo pipefail

# Configuration
PYTHON_VERSION="3.12.10"
PYENV_ROOT="$HOME/.pyenv"
# Detect shell RC (bash/zsh)
SHELL_NAME=$(basename "$SHELL" 2>/dev/null || echo "bash")
SHELL_RC="$HOME/.${SHELL_NAME}rc"

# Required packages for Ubuntu/Debian
deps=( 
  build-essential libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev
  wget curl llvm libncursesw5-dev xz-utils tk-dev libxml2-dev libxmlsec1-dev
  libffi-dev liblzma-dev git
)

# Install build dependencies if apt-get is available
if command -v apt-get >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y "${deps[@]}"
elif ! command -v git >/dev/null || ! command -v curl >/dev/null; then
  echo "Error: git and curl are required. Please install them first." >&2
  exit 1
fi

# Install or update pyenv via official installer
curl -fsSL https://pyenv.run | bash

# Configure shell for pyenv
if ! grep -q 'pyenv init' "$SHELL_RC" 2>/dev/null; then
  cat << 'EOF' >> "$SHELL_RC"
# Pyenv configuration
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"
EOF
fi

# Load pyenv for current session
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init --path)"
eval "$(pyenv init -)"

# Install specified Python and set global
if ! pyenv versions --bare | grep -qx "$PYTHON_VERSION"; then
  pyenv install "$PYTHON_VERSION"
fi
pyenv global "$PYTHON_VERSION"

echo "\n✅ Python $PYTHON_VERSION is installed and set as global. Restart your shell to apply changes."
