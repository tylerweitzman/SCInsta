#!/bin/bash

# Exit on error
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Display available tweaks
function list_available_tweaks() {
    echo -e "Available tweaks:"
    for dir in BH*; do
        if [ -d "$dir" ]; then
            echo "  - $(basename "$dir")"
        fi
    done
}

# Check if tweak directory argument is provided
if [ "$#" -lt 1 ]; then
    echo -e "${RED}Error: No tweak specified${NC}"
    echo -e "Usage: $0 <TweakDirectory> [sideload|rootless|rootful]"
    list_available_tweaks
    exit 1
fi

TWEAK_DIR="$1"
BUILD_TYPE="${2:-sideload}"  # Default to sideload if not specified

# Check if tweak directory exists
if [ ! -d "$TWEAK_DIR" ]; then
    echo -e "${RED}Error: Tweak directory $TWEAK_DIR not found!${NC}"
    list_available_tweaks
    exit 1
fi

# Check if jq is installed for JSON parsing
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Installing jq for JSON parsing...${NC}"
    brew install jq
fi

# Get config data from JSON file
CONFIG_FILE="tweaks.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: $CONFIG_FILE not found!${NC}"
    echo -e "Please create a configuration file with app-specific settings."
    exit 1
fi

# Attempt to load tweak configuration from JSON
if jq -e ".$TWEAK_DIR" "$CONFIG_FILE" &> /dev/null; then
    # Config exists for this tweak
    APP_URL=$(jq -r ".$TWEAK_DIR.app_url" "$CONFIG_FILE")
    APP_PACKAGE=$(jq -r ".$TWEAK_DIR.app_package" "$CONFIG_FILE")
    APP_NAME=$(jq -r ".$TWEAK_DIR.app_name" "$CONFIG_FILE")
    MIN_IOS=$(jq -r ".$TWEAK_DIR.min_ios_version" "$CONFIG_FILE")
    
    # Get SDK version from config if available
    if jq -e ".$TWEAK_DIR.sdk_version" "$CONFIG_FILE" &> /dev/null; then
        SDK_VERSION=$(jq -r ".$TWEAK_DIR.sdk_version" "$CONFIG_FILE")
    else
        SDK_VERSION="iPhoneOS14.5.sdk"  # Default SDK if not specified
    fi
else
    # Auto-discover folders without explicit config
    # Create a minimal entry based on tweak directory name
    echo -e "${YELLOW}No explicit configuration found for $TWEAK_DIR, using defaults.${NC}"
    echo -e "${YELLOW}Consider adding this tweak to $CONFIG_FILE for better control.${NC}"
    
    # Default values based on naming conventions
    APP_NAME=$(echo "$TWEAK_DIR" | sed 's/^BH//')
    APP_PACKAGE="com.example.$APP_NAME"
    APP_URL=""
    MIN_IOS="15.0"
    SDK_VERSION="iPhoneOS14.5.sdk"  # Default SDK
fi

# Get the actual tweak name from the control file
TWEAK_NAME=$(awk '/Name:/ {print $2}' "$TWEAK_DIR/control")
if [ -z "$TWEAK_NAME" ]; then
    TWEAK_NAME="$TWEAK_DIR"  # Fallback to directory name
fi

# Configuration
THEOS_DIR="$HOME/theos"
SDK_DIR="$THEOS_DIR/sdks"
# SDK_VERSION is now set from the config
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Export THEOS environment variable
export THEOS="$THEOS_DIR"
export THEOS_MAKE_PATH="$THEOS_DIR/makefiles"

echo -e "${GREEN}Starting local build of $TWEAK_NAME ($TWEAK_DIR)...${NC}"

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
if ! brew list ldid dpkg make svn &>/dev/null; then
    brew install ldid dpkg make svn
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
echo -e "${YELLOW}Setting up iOS SDK (${SDK_VERSION})...${NC}"
if [ ! -d "$SDK_DIR/$SDK_VERSION" ]; then
    mkdir -p "$SDK_DIR"
    
    # Use Git sparse-checkout to download only the specific SDK
    echo -e "${YELLOW}Downloading $SDK_VERSION using Git sparse-checkout...${NC}"
    
    # GitHub repository details
    # GITHUB_REPO="xybp888/iOS-SDKs"
    GITHUB_REPO="theos/sdks"
    GITHUB_URL="https://github.com/$GITHUB_REPO.git"
    
    # Create a temporary directory for the sparse checkout
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Initialize git and set up sparse checkout
    echo -e "${YELLOW}Initializing sparse checkout...${NC}"
    git init --quiet
    git remote add origin "$GITHUB_URL"
    
    # Enable sparse checkout
    git config core.sparseCheckout true
    
    # Specify only the SDK directory to download
    echo "$SDK_VERSION" > .git/info/sparse-checkout
    
    # Function to display a spinner animation
    spinner() {
        local pid=$1
        local delay=0.1
        local spinstr='|/-\'
        while [ "$(ps -p $pid | grep -c $pid)" -eq 1 ]; do
            local temp=${spinstr#?}
            printf " [%c]  " "$spinstr"
            local spinstr=$temp${spinstr%"$temp"}
            sleep $delay
            printf "\b\b\b\b\b\b"
        done
        printf "    \b\b\b\b"
    }
    
    # Fetch only the latest commit (depth=1) to save bandwidth
    echo -ne "${YELLOW}Fetching $SDK_VERSION directory...${NC}"
    git pull --depth=1 origin master > /dev/null 2>&1 & 
    spinner $!
    
    # Check if pull was successful
    if [ -d "$SDK_VERSION" ]; then
        echo -e "\n${GREEN}Successfully downloaded $SDK_VERSION${NC}"
        # Copy the SDK to the final destination
        cp -R "$SDK_VERSION" "$SDK_DIR/"
        echo -e "${GREEN}SDK installed successfully!${NC}"
    else
        echo -e "\n${RED}SDK $SDK_VERSION not found in the repository.${NC}"
        echo -e "${YELLOW}Checking available SDKs...${NC}"
        
        # Switch to listing all available SDKs using a different sparse-checkout
        echo "*.sdk" > .git/info/sparse-checkout
        git read-tree -mu HEAD
        
        echo -ne "${YELLOW}Fetching list of available SDKs...${NC}"
        git pull --depth=1 origin master > /dev/null 2>&1 &
        spinner $!
        
        if [ $? -eq 0 ]; then
            echo -e "\n${YELLOW}Available SDKs:${NC}"
            find . -maxdepth 1 -name "*.sdk" -type d | sort | while read sdk; do
                echo "  - $(basename "$sdk")"
            done
        else
            echo -e "\n${RED}Failed to check available SDKs.${NC}"
            echo -e "${RED}Please check the repository manually at:${NC}"
            echo -e "${YELLOW}https://github.com/$GITHUB_REPO${NC}"
        fi
        
        echo -e "${RED}Please update tweaks.json with an available SDK version.${NC}"
        cd - > /dev/null
        rm -rf "$TMP_DIR"
        exit 1
    fi
    
    # Return to original directory and clean up
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    
    # Verify SDK was installed correctly
    if [ ! -d "$SDK_DIR/$SDK_VERSION" ]; then
        echo -e "${RED}Failed to install $SDK_VERSION.${NC}"
        echo -e "${RED}Please download it manually from https://github.com/$GITHUB_REPO${NC}"
        echo -e "${RED}and place it in $SDK_DIR/${NC}"
        exit 1
    else
        echo -e "${GREEN}SDK $SDK_VERSION successfully installed!${NC}"
    fi
else
    echo "SDK already exists, skipping download..."
fi

# Check if App URL is provided
if [ -z "$APP_URL" ]; then
    echo -e "${RED}Error: $APP_NAME URL is not set. Please update $CONFIG_FILE with the URL for $TWEAK_DIR.${NC}"
    exit 1
fi

# Change to project root directory
cd "$PROJECT_ROOT"

# Prepare App IPA
echo -e "${YELLOW}Downloading $APP_NAME IPA...${NC}"
mkdir -p packages
if [ ! -f "packages/$APP_PACKAGE.ipa" ]; then
    wget "$APP_URL" --progress=bar -O "packages/$APP_PACKAGE.ipa"
else
    echo "$APP_NAME IPA already exists, skipping download..."
fi

# Get tweak version
echo -e "${YELLOW}Getting $TWEAK_NAME version...${NC}"
if [ ! -f "$TWEAK_DIR/control" ]; then
    echo -e "${RED}Error: control file not found in $PROJECT_ROOT/$TWEAK_DIR${NC}"
    exit 1
fi
TWEAK_VERSION=$(awk '/Version:/ {print $2}' "$TWEAK_DIR/control")
echo "Building version: $TWEAK_VERSION"

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

# Add GNU Make to PATH
export PATH="$(brew --prefix)/opt/make/libexec/gnubin:$PATH"

# Set number of parallel jobs to number of CPU cores
export THEOS_JOBS=$(sysctl -n hw.ncpu)
echo -e "${YELLOW}Building with ${THEOS_JOBS} parallel jobs...${NC}"

# Create temporary links to tweak files
echo -e "${YELLOW}Setting up build for $TWEAK_NAME...${NC}"
ln -sf "$TWEAK_DIR/control" control
mkdir -p .tweak_temp
cp -R "$TWEAK_DIR/"* .tweak_temp/

# Run the build
echo -e "${YELLOW}Building $TWEAK_NAME...${NC}"
./build.sh "$BUILD_TYPE" "$TWEAK_DIR"

# Rename the output IPA
echo -e "${YELLOW}Renaming output IPA...${NC}"
cd packages
LATEST_IPA=$(ls -t | grep .ipa | head -n1)
mv "$LATEST_IPA" "${TWEAK_NAME}_${BUILD_TYPE}_v${TWEAK_VERSION}.ipa"

# Clean up temporary files
cd "$PROJECT_ROOT"
rm -f control
rm -rf .tweak_temp

echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "Output file: ${YELLOW}packages/${TWEAK_NAME}_${BUILD_TYPE}_v${TWEAK_VERSION}.ipa${NC}" 