#!/bin/bash
set -e

# Default values
[ -z "$DOMAIN" ] && DOMAIN="xiaomi_miot"
[ -z "$REPO_PATH" ] && REPO_PATH="al-one/hass-xiaomi-miot"
REPO_NAME=$(basename "$REPO_PATH")
[ -z "$ARCHIVE_TAG" ] && ARCHIVE_TAG="$1"
[ -z "$ARCHIVE_TAG" ] && ARCHIVE_TAG="master"
[ -z "$HUB_DOMAIN" ] && HUB_DOMAIN="github.com"

# Colors for output
RED_COLOR='\033[0;31m'
GREEN_COLOR='\033[0;32m'
GREEN_YELLOW='\033[1;33m'
NO_COLOR='\033[0m'

# Functions
info() { echo -e "${GREEN_COLOR}INFO: $1${NO_COLOR}"; }
warn() { echo -e "${GREEN_YELLOW}WARN: $1${NO_COLOR}"; }
error() { echo -e "${RED_COLOR}ERROR: $1${NO_COLOR}"; [ "$2" != "false" ] && exit 1; }

checkRequirement() {
  if [ -z "$(command -v "$1")" ]; then
    error "'$1' is not installed"
  fi
}

findConfigPath() {
  declare -a paths=(
    "$PWD"
    "$PWD/config"
    "/config"
    "$HOME/.homeassistant"
    "/usr/share/hassio/homeassistant"
  )

  for path in "${paths[@]}"; do
    if [ -f "$path/home-assistant.log" ]; then
      haPath="$path"
      break
    elif [ -d "$path/.storage" ] && [ -f "$path/configuration.yaml" ]; then
      haPath="$path"
      break
    fi
  done
}

# Main script
checkRequirement "wget"
checkRequirement "unzip"

findConfigPath

if [ -n "$haPath" ]; then
  info "Found Home Assistant configuration directory at '$haPath'"
  cd "$haPath" || error "Could not change path to $haPath"

  # Determine archive URL
  if [ "$ARCHIVE_TAG" = "latest" ]; then
    ARCHIVE_URL="https://$HUB_DOMAIN/$REPO_PATH/releases/$ARCHIVE_TAG/download/$DOMAIN.zip"
  elif [ "$DOMAIN" = "hacs" ] && ([ "$ARCHIVE_TAG" = "main" ] || [ "$ARCHIVE_TAG" = "china" ]); then
    ARCHIVE_TAG="latest"
    ARCHIVE_URL="https://$HUB_DOMAIN/$REPO_PATH/releases/$ARCHIVE_TAG/download/$DOMAIN.zip"
  else
    ARCHIVE_URL="https://$HUB_DOMAIN/$REPO_PATH/archive/$ARCHIVE_TAG.zip"
  fi
  
  # Download and install
info "Archive URL: $ARCHIVE_URL"
info "Changing to the custom_components directory..."
custom_components_path="$haPath/custom_components"
mkdir -p "$custom_components_path"
cd "$custom_components_path" || error "Could not change path to $custom_components_path"
info "Downloading..."
wget -t 2 -O "$custom_components_path/$ARCHIVE_TAG.zip" "$ARCHIVE_URL"

info "Unpacking..."
unzip -o "$custom_components_path/$ARCHIVE_TAG.zip" -d "$custom_components_path" >/dev/null 2>&1
repo_dir="$custom_components_path/$REPO_NAME-$ARCHIVE_TAG"

if [ -d "$custom_components_path/$DOMAIN" ]; then
    warn "custom_components/$DOMAIN directory already exists, cleaning up..."
    rm -R "$custom_components_path/$DOMAIN"
fi

if [ -d "$repo_dir/custom_components/$DOMAIN" ]; then
    info "Copying files..."
    cp -r "$repo_dir/custom_components/$DOMAIN" "$custom_components_path"
else
    error "Could not find custom_components/$DOMAIN directory in the archive" false
fi

info "Removing temporary files..."
rm -rf "$custom_components_path/$ARCHIVE_TAG.zip"
rm -rf "$repo_dir"
info "Installation complete."
info "Remember to restart Home Assistant before you configure it."

else
  error "Could not find the directory for Home Assistant" false
  echo "Manually change the directory to the root of your Home Assistant configuration"
  echo "With the user that is running Home Assistant and run the script again"
  exit 1
fi
