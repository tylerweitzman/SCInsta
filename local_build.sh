#!/bin/bash

# Exit on error
set -e

# Configuration
INSTAGRAM_URL="https://und3fy-my.sharepoint.com/personal/5decrypt_und3fy_onmicrosoft_com/_layouts/15/download.aspx?share=EaWzJ5Xp5vZCi7K_cyyJPIkB4IRDy94ACbn8l4OW-rKgtQ"
THEOS_DIR="$HOME/theos"
SDK_DIR="$THEOS_DIR/sdks"
SDK_VERSION="iPhoneOS14.5.sdk"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Export THEOS environment variable
export THEOS="$THEOS_DIR"
export THEOS_MAKE_PATH="$THEOS_DIR/makefiles"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting local build of SCInsta...${NC}"

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo -e "${RED}Error: This script must be run on macOS${NC}"
    exit 1
fi

# Check if required tools are installed
echo -e "${YELLOW}Checking dependencies...${NC}"
if ! command -v brew &> /dev/null; then
    echo -e "${RED}Error: Homebrew is not installed. Please install it first.${NC}"
    exit 1
fi

# Install required packages
echo -e "${YELLOW}Installing required packages...${NC}"
if ! brew list ldid dpkg make &>/dev/null; then
    brew install ldid dpkg make
else
    echo "Required packages are already installed"
fi

# Setup Theos
echo -e "${YELLOW}Setting up Theos...${NC}"
if [ ! -d "$THEOS_DIR" ]; then
    git clone --recursive https://github.com/theos/theos.git "$THEOS_DIR"
else
    echo "Theos already exists, updating..."
    cd "$THEOS_DIR" && git pull && git submodule update --init --recursive
fi

# Setup SDK
echo -e "${YELLOW}Setting up iOS SDK...${NC}"
if [ ! -d "$SDK_DIR/$SDK_VERSION" ]; then
    mkdir -p "$SDK_DIR"
    git clone --quiet -n --depth=1 --filter=tree:0 https://github.com/xybp888/iOS-SDKs/
    cd iOS-SDKs
    git sparse-checkout set --no-cone "$SDK_VERSION"
    git checkout
    mv *.sdk "$SDK_DIR"
    cd ..
    rm -rf iOS-SDKs
else
    echo "SDK already exists, skipping download..."
fi

# Check if Instagram URL is provided
if [ -z "$INSTAGRAM_URL" ]; then
    echo -e "${RED}Error: INSTAGRAM_URL is not set. Please edit the script and set the INSTAGRAM_URL variable.${NC}"
    exit 1
fi

# Change to project root directory
cd "$PROJECT_ROOT"

# Prepare Instagram IPA
echo -e "${YELLOW}Downloading Instagram IPA...${NC}"
mkdir -p packages
if [ ! -f packages/com.burbn.instagram.ipa ]; then
    wget "$INSTAGRAM_URL" --progress=bar -O packages/com.burbn.instagram.ipa
else
    echo "Instagram IPA already exists, skipping download..."
fi

# Get SCInsta version
echo -e "${YELLOW}Getting SCInsta version...${NC}"
if [ ! -f "control" ]; then
    echo -e "${RED}Error: control file not found in $PROJECT_ROOT${NC}"
    exit 1
fi
SCINSTA_VERSION=$(awk '/Version:/ {print $2}' control)
echo "Building version: $SCINSTA_VERSION"

# Build the tweak
echo -e "${YELLOW}Building SCInsta tweak...${NC}"

# Check if pyzule is already configured
if [ ! -f "$HOME/.config/pyzule/version.json" ] || [ ! -x "$(command -v pyzule)" ]; then
    echo -e "${YELLOW}Installing pyzule...${NC}"
    bash install-pyzule.sh
else
    echo -e "${GREEN}pyzule is already configured, skipping installation...${NC}"
fi

# Ensure THEOS environment is properly set
echo -e "${YELLOW}Setting up build environment...${NC}"
export PATH="$THEOS/bin:$PATH"
export THEOS_MAKE_PATH="$THEOS/makefiles"

# Add GNU Make to PATH (before running build.sh)
export PATH="$(brew --prefix)/opt/make/libexec/gnubin:$PATH"

# Set number of parallel jobs to number of CPU cores
export THEOS_JOBS=$(sysctl -n hw.ncpu)
echo -e "${YELLOW}Building with ${THEOS_JOBS} parallel jobs...${NC}"

# Run the build
./build.sh sideload

# Rename the output IPA
echo -e "${YELLOW}Renaming output IPA...${NC}"
cd packages
LATEST_IPA=$(ls -t | head -n1)
mv "$LATEST_IPA" "SCInsta_sideloaded_v${SCINSTA_VERSION}.ipa"

echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "Output file: ${YELLOW}packages/SCInsta_sideloaded_v${SCINSTA_VERSION}.ipa${NC}" 