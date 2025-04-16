#!/usr/bin/env bash

set -e

CMAKE_OSX_ARCHITECTURES="arm64e;arm64"

# Get the tweak name from the argument (directory name)
TWEAK_DIR="${2:-BHInstagram}"  # Default to BHInstagram if not provided

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if jq is installed for JSON parsing
if ! command -v jq &> /dev/null; then
    echo -e "${YELLOW}Installing jq for JSON parsing...${NC}"
    brew install jq
fi

# Prerequisites for FLEX (only needed for old SCInsta)
if [ "$TWEAK_DIR" = "SCInsta" ] && [ -z "$(ls -A modules/libflex/FLEX)" ]; then
    echo -e '\033[1m\033[0;31mFLEX submodule not found.\nPlease run the following command to checkout submodules:\n\n\033[0m    git submodule update --init --recursive'
    exit 1
fi

# Check if tweak directory exists
if [ ! -d "$TWEAK_DIR" ]; then
    echo -e "${RED}Error: Tweak directory $TWEAK_DIR not found!${NC}"
    exit 1
fi

# Get config data from JSON file
CONFIG_FILE="tweaks.json"
if [ ! -f "$CONFIG_FILE" ]; then
    echo -e "${RED}Error: $CONFIG_FILE not found!${NC}"
    echo -e "Please create a configuration file with app-specific settings."
    exit 1
fi

# Load app configuration from JSON if available
IS_LEGACY_TWEAK=false
if jq -e ".$TWEAK_DIR" "$CONFIG_FILE" &> /dev/null; then
    # Config exists for this tweak
    APP_IDENTIFIER=$(jq -r ".$TWEAK_DIR.app_package" "$CONFIG_FILE")
    APP_NAME=$(jq -r ".$TWEAK_DIR.app_name" "$CONFIG_FILE")
    MIN_IOS=$(jq -r ".$TWEAK_DIR.min_ios_version" "$CONFIG_FILE")
    
    # Check if this is a legacy tweak (like SCInsta)
    if jq -e ".$TWEAK_DIR.legacy" "$CONFIG_FILE" &> /dev/null; then
        IS_LEGACY_TWEAK=$(jq -r ".$TWEAK_DIR.legacy" "$CONFIG_FILE")
    fi
else
    # Auto-discover folders without explicit config
    # Create a minimal entry based on tweak directory name
    echo -e "${YELLOW}No explicit configuration found for $TWEAK_DIR, using defaults.${NC}"
    
    # Default values based on naming conventions
    APP_NAME=$(echo "$TWEAK_DIR" | sed 's/^BH//')
    APP_IDENTIFIER="com.example.$APP_NAME"
    MIN_IOS="15.0"
fi

# Get the package and tweak name from the control file
PACKAGE_NAME=$(awk '/Package:/ {print $2}' "$TWEAK_DIR/control")
TWEAK_NAME=$(awk '/Name:/ {print $2}' "$TWEAK_DIR/control")

# If NAME isn't found in control file or is empty, use the directory name as fallback
if [ -z "$TWEAK_NAME" ]; then
    TWEAK_NAME="$TWEAK_DIR"
fi

# If PACKAGE_NAME isn't found, use fallback based on directory
if [ -z "$PACKAGE_NAME" ]; then
    PACKAGE_NAME="com.bandarhl.${TWEAK_DIR,,}"  # lowercase directory name
fi

echo -e "${YELLOW}Building package: ${PACKAGE_NAME} (${TWEAK_NAME})${NC}"
echo -e "${YELLOW}Target app: ${APP_NAME} (${APP_IDENTIFIER})${NC}"

# Building modes
if [ "$1" == "sideload" ]; then
    # Clean build artifacts
    make clean
    rm -rf .theos

    # Check for decrypted app IPA
    ipaFile="$(find ./packages_source/*${APP_IDENTIFIER}*.ipa -type f -exec basename {} \;)"
    if [ -z "${ipaFile}" ]; then
        echo -e "${RED}./packages/${APP_IDENTIFIER}.ipa not found.\nPlease put a decrypted ${APP_NAME} IPA in its path.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Building ${TWEAK_NAME} tweak for sideloading (as IPA)${NC}"

    # Check if building with dev mode
    if [ "$3" == "--dev" ]; then
        if [ "$IS_LEGACY_TWEAK" = "true" ]; then
            FLEXPATH='packages/libsciFLEX.dylib'
            make "DEV=1"
        else
            # For other tweaks that might not use FLEX
            make -C "$TWEAK_DIR" "DEV=1"
        fi
    else
        if [ "$IS_LEGACY_TWEAK" = "true" ]; then
            FLEXPATH='.theos/obj/debug/libsciFLEX.dylib'
            make "SIDELOAD=1"
        else
            # Use the tweak's Makefile directly
            cd "$TWEAK_DIR" && make "SIDELOAD=1"
            cd ..
        fi
    fi

    # Create IPA File
    echo -e "${GREEN}Creating the IPA file...${NC}"
    rm -f "packages/${TWEAK_NAME}-sideloaded.ipa"
    
    if [ "$IS_LEGACY_TWEAK" = "true" ]; then
        pyzule -i "packages/${ipaFile}" -o "packages/${TWEAK_NAME}-sideloaded.ipa" -f .theos/obj/debug/SCInsta.dylib .theos/obj/debug/sideloadfix.dylib $FLEXPATH -c 0 -m $MIN_IOS -du
    else
        # For other tweaks, determine the dylib name from the Makefile or control
        DYLIB_NAME="$(grep "TWEAK_NAME" "$TWEAK_DIR/Makefile" | cut -d "=" -f2 | tr -d ' ')"
        if [ -z "$DYLIB_NAME" ]; then
            # If not found in Makefile, use the package name without the domain part
            DYLIB_NAME="$(echo "$PACKAGE_NAME" | rev | cut -d "." -f1 | rev)"
        fi
        
        # Try multiple potential locations for the dylib
        DYLIB_PATH=".theos/obj/debug/${DYLIB_NAME}.dylib"
        if [ ! -f "$DYLIB_PATH" ]; then
            DYLIB_PATH="$TWEAK_DIR/.theos/obj/debug/${DYLIB_NAME}.dylib"
        fi
        
        if [ ! -f "$DYLIB_PATH" ]; then
            echo -e "${RED}Could not find dylib at ${DYLIB_PATH}${NC}"
            echo -e "${YELLOW}Trying alternative dylib name: ${PACKAGE_NAME}.dylib${NC}"
            
            # Try with the full package name as fallback
            DYLIB_PATH=".theos/obj/debug/${PACKAGE_NAME}.dylib"
            if [ ! -f "$DYLIB_PATH" ]; then
                DYLIB_PATH="$TWEAK_DIR/.theos/obj/debug/${PACKAGE_NAME}.dylib"
            fi
            
            if [ ! -f "$DYLIB_PATH" ]; then
                echo -e "${RED}Could not find dylib. Build may have failed.${NC}"
                exit 1
            fi
        fi
        
        # Check if the tweak uses a sideloadfix
        if [ -f "$TWEAK_DIR/.theos/obj/debug/sideloadfix.dylib" ]; then
            EXTRA_DYLIBS="$TWEAK_DIR/.theos/obj/debug/sideloadfix.dylib"
        elif [ -f ".theos/obj/debug/sideloadfix.dylib" ]; then
            EXTRA_DYLIBS=".theos/obj/debug/sideloadfix.dylib"
        else
            EXTRA_DYLIBS=""
        fi
        
        echo -e "${GREEN}Using dylib: ${DYLIB_PATH}${NC}"
        pyzule -i "packages_source/${ipaFile}" -o "packages/${TWEAK_NAME}-sideloaded.ipa" -f "$DYLIB_PATH" $EXTRA_DYLIBS -c 0 -m $MIN_IOS -du
    fi
    
    echo -e "${GREEN}Done, we hope you enjoy ${TWEAK_NAME}!${NC}\n\nYou can find the ipa file at: $(pwd)/packages"

elif [ "$1" == "rootless" ]; then
    # Clean build artifacts
    make clean
    rm -rf .theos

    echo -e "${GREEN}Building ${TWEAK_NAME} tweak for rootless${NC}"

    export THEOS_PACKAGE_SCHEME=rootless
    
    if [ "$IS_LEGACY_TWEAK" = "true" ]; then
        make package
    else
        # Use the tweak's Makefile directly
        cd "$TWEAK_DIR" && make package
        # Copy the resulting deb file to the main packages directory
        mkdir -p ../packages
        cp packages/*.deb ../packages/
        cd ..
    fi

    echo -e "${GREEN}Done, we hope you enjoy ${TWEAK_NAME}!${NC}\n\nYou can find the deb file at: $(pwd)/packages"

elif [ "$1" == "rootful" ]; then
    # Clean build artifacts
    make clean
    rm -rf .theos

    echo -e "${GREEN}Building ${TWEAK_NAME} tweak for rootful${NC}"

    unset THEOS_PACKAGE_SCHEME
    
    if [ "$IS_LEGACY_TWEAK" = "true" ]; then
        make package
    else
        # Use the tweak's Makefile directly
        cd "$TWEAK_DIR" && make package
        # Copy the resulting deb file to the main packages directory
        mkdir -p ../packages
        cp packages/*.deb ../packages/
        cd ..
    fi

    echo -e "${GREEN}Done, we hope you enjoy ${TWEAK_NAME}!${NC}\n\nYou can find the deb file at: $(pwd)/packages"

else
    echo '+--------------------+'
    echo '|Tweak Build Script  |'
    echo '+--------------------+'
    echo
    echo 'Usage: ./build.sh <sideload/rootless/rootful> [TWEAK_DIR]'
    exit 1
fi