#!/usr/bin/env bash

set -e

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run this script with sudo or as root."
  exit 1
fi

# Get the real user who invoked sudo (for user-level configuration)
REAL_USER=${SUDO_USER:-$USER}
if [ "$REAL_USER" = "root" ]; then
  echo "Error: Do not run this script directly as the root user. Run it as a normal user using 'sudo ./setup.sh'."
  exit 1
fi

REAL_HOME=$(eval echo "~$REAL_USER")
DOTFILES_BASE_URL="${DOTFILES_BASE_URL:-https://raw.githubusercontent.com/sadako-yamamura/arch/zsh/dotfiles}"

echo "==> Updating system package databases..."
pacman -Sy --noconfirm

# 1. Extra packages
echo "==> Installing optional system tools..."
pacman -S --needed --noconfirm \
    tmux \
    vim \
    kitty \
    firefox \
    zsh \
    starship \
    ttf-firacode-nerd \
    fzf \
    less \
    bat \
    eza \
    fd \
    zoxide \
    ripgrep \
    yazi \
    jq \
    tealdeer \
    openssh

# 2. Blackarch
echo "==> Setting up BlackArch official repositories..."
curl -O https://blackarch.org/strap.sh
chmod +x strap.sh
./strap.sh
rm strap.sh
echo "==> Refreshing package databases..."
pacman -Sy --noconfirm

# 3. Arkenfox
echo "==> Installing Arkenfox user.js for $REAL_USER..."
sudo -u "$REAL_USER" env HOME="$REAL_HOME" bash -c '
  set -e

  FIREFOX_PROFILE_ROOT="$HOME/.mozilla/firefox"
  PROFILE_DIR=$(find "$FIREFOX_PROFILE_ROOT" -mindepth 1 -maxdepth 1 \
    -type d -name "*.default*" -print -quit 2>/dev/null || true)

  # Create Firefox’s default profile if this is a fresh installation.
  if [ -z "$PROFILE_DIR" ]; then
    firefox --headless -CreateProfile default >/dev/null 2>&1 || true
    PROFILE_DIR=$(find "$FIREFOX_PROFILE_ROOT" -mindepth 1 -maxdepth 1 \
      -type d -name "*.default*" -print -quit 2>/dev/null || true)
  fi

  if [ -z "$PROFILE_DIR" ]; then
    echo "Warning: no Firefox profile found; Arkenfox was not applied."
    exit 0
  fi

  if [ -f "$PROFILE_DIR/user.js" ]; then
    cp -p "$PROFILE_DIR/user.js" \
      "$PROFILE_DIR/user.js.backup.$(date +%Y%m%d%H%M%S)"
  fi

  curl --fail --silent --show-error --location \
    https://raw.githubusercontent.com/arkenfox/user.js/master/user.js \
    --output "$PROFILE_DIR/user.js"
  echo "Arkenfox applied to $PROFILE_DIR"
'

# 4. Zsh config
echo "==> Setting Zsh as the login shell for $REAL_USER..."
ZSH_PATH=$(command -v zsh)
chsh -s "$ZSH_PATH" "$REAL_USER"

echo "==> Configuring tmux to start Zsh..."
sudo -u "$REAL_USER" env HOME="$REAL_HOME" bash -c '
  TMUX_CONFIG="$HOME/.tmux.conf"
  touch "$TMUX_CONFIG"

  grep -Fqx "set -g default-shell /bin/zsh" "$TMUX_CONFIG" || \
    echo "set -g default-shell /bin/zsh" >> "$TMUX_CONFIG"
  grep -Fqx "set -g default-command \"/bin/zsh -l\"" "$TMUX_CONFIG" || \
    echo "set -g default-command \"/bin/zsh -l\"" >> "$TMUX_CONFIG"
'

# 5. Kitty
echo "==> Configuring Kitty theme for $REAL_USER..."
sudo -u "$REAL_USER" bash -c "
  mkdir -p '$REAL_HOME/.config/kitty'
  KITTY_CONFIG='$REAL_HOME/.config/kitty/kitty.conf'
  grep -Fqx 'font_family FiraCode Nerd Font' \"\$KITTY_CONFIG\" || \\
    echo 'font_family FiraCode Nerd Font' >> \"\$KITTY_CONFIG\"
  kitty +kitten themes --reload-in=all Catppuccin-Mocha
"

echo "==> Installing public dotfiles for $REAL_USER..."
sudo -u "$REAL_USER" env HOME="$REAL_HOME" DOTFILES_BASE_URL="$DOTFILES_BASE_URL" bash -c '
  set -e

  DOTFILES_TMP=$(mktemp -d)
  trap "rm -rf \"$DOTFILES_TMP\"" EXIT

  fetch_config() {
    remote_path="$1"
    target_file="$2"
    source_file="$DOTFILES_TMP/$(basename "$target_file")"

    curl --fail --silent --show-error --location \
      "$DOTFILES_BASE_URL/$remote_path" --output "$source_file"

    if [ -f "$target_file" ]; then
      cp -p "$target_file" "$target_file.backup.$(date +%Y%m%d%H%M%S)"
    fi

    install -Dm644 "$source_file" "$target_file"
  }

  fetch_config ".zshrc" "$HOME/.zshrc"
  fetch_config ".config/starship.toml" "$HOME/.config/starship.toml"
  fetch_config ".mozilla/firefox/user.js" "$HOME/.mozilla/firefox/user.js"
'

echo "==> Setup finished successfully!"
