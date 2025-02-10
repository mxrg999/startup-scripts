#!/usr/bin/env bash

################################################################################
# This script is intended for Debian/Ubuntu-based systems.
#
# It will do the following:
#
#  1. Update and upgrade apt packages.
#  2. Install the following packages: fish, git, curl, wget, tmux, nodejs, npm, openssh-client.
#  3. Add fish to /etc/shells (if not present) and set fish as the default shell.
#  4. Install Fisher and the Tide prompt in fish.
#  5. Clone your dotfiles into a bare repository at ~/.dotfiles and reset them onto ~.
#  6. Ask if you want to install Neovim from source. If yes, it will:
#       - Remove any existing neovim package.
#       - Install build dependencies (ninja-build, gettext, cmake, unzip, curl).
#       - Clone the Neovim repo, build it, and install via a .deb package.
#       - Clean up any leftover files.
#  7. Install tmux plugin manager (TPM) and source your tmux config.
#
# You can exit any time before confirming a step.
################################################################################

set -e  # Exit immediately on error

echo "========================================================"
echo " This script is intended for Debian/Ubuntu-based systems."
echo ""
echo " Here is what will be done:"
echo "  1. apt update & upgrade"
echo "  2. apt install: fish, git, curl, wget, tmux, nodejs, npm, openssh-client"
echo "  3. Add fish to /etc/shells and make it the default shell"
echo "  4. Install Fisher and Tide prompt in fish"
echo "  5. Clone your dotfiles (bare repo) and reset your HOME"
echo "  6. (Optional) Build & install Neovim from source"
echo "  7. Install tmux plugin manager (TPM) and source config"
echo "========================================================"
read -rp "Do you want to proceed? (y/N) " PROCEED

if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
  echo "Aborting script."
  exit 1
fi

################################################################################
# 1. Update and upgrade apt packages
################################################################################
echo "==> Updating and upgrading apt packages..."
sudo apt update && sudo apt upgrade -y

################################################################################
# 2. Install packages
################################################################################
PACKAGES="fish git curl wget tmux nodejs npm openssh-client"

echo "==> Installing required packages: $PACKAGES"
sudo apt install -y $PACKAGES

################################################################################
# 3. Add fish to /etc/shells and make it the default shell
################################################################################
echo "==> Adding fish to /etc/shells (if not already present)..."
FISH_PATH="$(command -v fish)"
if ! grep -Fxq "$FISH_PATH" /etc/shells; then
  echo "$FISH_PATH" | sudo tee -a /etc/shells
fi

echo "==> Changing default shell to fish..."
chsh -s "$FISH_PATH"

################################################################################
# 4. Install Fisher and the Tide prompt in fish
################################################################################
echo "==> Installing Fisher and Tide in fish..."
fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher && fisher install IlanCosman/tide@v6'

################################################################################
# 5. Clone dotfiles (bare repo) and reset onto ~
################################################################################
echo "==> Cloning dotfiles into ~/.dotfiles (bare repo)..."
git clone --bare https://github.com/mxrg999/dotfiles.git "$HOME/.dotfiles" || true

# Define a function to manage dotfiles
function dotfiles {
  /usr/bin/git --git-dir="$HOME/.dotfiles" --work-tree="$HOME" "$@"
}

echo "==> Configuring dotfiles to hide untracked files..."
dotfiles config --local status.showUntrackedFiles no

echo "==> Resetting dotfiles in HOME..."
dotfiles reset --hard

################################################################################
# 6. (Optional) Build & install Neovim from source
################################################################################
read -rp "Do you want to install Neovim from source? (y/N) " INSTALL_NVIM
if [[ "$INSTALL_NVIM" =~ ^[Yy]$ ]]; then
  echo "==> Removing existing Neovim (if any)..."
  sudo apt remove -y neovim || true

  echo "==> Installing Neovim build dependencies..."
  sudo apt update
  sudo apt install -y ninja-build gettext cmake unzip curl

  echo "==> Cloning Neovim repository..."
  git clone https://github.com/neovim/neovim
  cd neovim

  echo "==> Building Neovim (RelWithDebInfo)..."
  make CMAKE_BUILD_TYPE=RelWithDebInfo

  echo "==> Creating Debian package..."
  cd build
  cpack -G DEB

  echo "==> Installing Neovim .deb (force-overwrite if needed)..."
  sudo dpkg -i --force-overwrite nvim-linux64.deb || true

  echo "==> Fixing missing dependencies (if any)..."
  sudo apt-get install -f -y

  echo "==> Cleaning up Neovim source..."
  cd ../..
  rm -rf neovim

  echo "==> Neovim installation complete!"
else
  echo "==> Skipping Neovim installation."
fi

################################################################################
# 7. Install tmux plugin manager (TPM) and source tmux config
################################################################################
echo "==> Installing tmux plugin manager (TPM)..."
[ -d "$HOME/.tmux/plugins" ] || mkdir -p "$HOME/.tmux/plugins"
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
  git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
fi

echo "==> Sourcing tmux configuration (if available at ~/.config/tmux/tmux.conf)..."
if [[ -f "$HOME/.config/tmux/tmux.conf" ]]; then
  tmux source-file "$HOME/.config/tmux/tmux.conf" || true
fi

echo ""
echo "========================================================"
echo " All tasks have been completed!"
echo " - If you changed your default shell to fish, log out/in"
echo "   or open a new terminal to start using fish."
echo " - If you installed Neovim, you can launch 'nvim' now."
echo "========================================================"

