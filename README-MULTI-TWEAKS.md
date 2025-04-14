# Multi-Tweak Structure

This repository has been refactored to support building multiple tweaks from a single codebase. Currently, it supports:

- **BHInstagram**: Instagram tweak (outputs "BHInsta" IPA)
- **BHTikTok**: TikTok tweak (WIP)

## Directory Structure

Each tweak has its own directory (e.g., `BHInstagram/`, `BHTikTok/`) containing all the files needed for that specific tweak:

```
RepoRoot/
├── BHInstagram/               # Instagram tweak files
│   ├── Tweak.x               # Main tweak code
│   ├── control               # Package metadata (defines Name: BHInsta)
│   ├── Makefile              # Build instructions
│   └── ...                   # Other tweak-specific files
│
├── BHTikTok/                  # TikTok tweak files (similar structure)
│
├── modules/                   # Shared modules and dependencies
├── build.sh                   # Build script (supports multiple tweaks)
├── local_build.sh             # Local build script (supports multiple tweaks)
└── tweaks.json                # Configuration for all tweaks
```

## Configuration File

The repository uses a central `tweaks.json` file to store app-specific configurations. This allows adding new tweaks without modifying the build scripts:

```json
{
  "BHInstagram": {
    "app_url": "https://example.com/instagram.ipa",
    "app_package": "com.burbn.instagram",
    "app_name": "Instagram",
    "min_ios_version": "15.0"
  },
  "BHTikTok": {
    "app_url": "https://example.com/tiktok.ipa",
    "app_package": "com.zhiliaoapp.musically",
    "app_name": "TikTok",
    "min_ios_version": "15.0"
  }
}
```

## Building a Tweak

To build a tweak, use the local_build.sh script with the tweak directory name:

```bash
# Build Instagram tweak (sideload is the default build type)
bash local_build.sh BHInstagram

# Build TikTok tweak with a specific build type
bash local_build.sh BHTikTok sideload

# Other build types
bash local_build.sh BHInstagram rootless
bash local_build.sh BHInstagram rootful
```

## How it Works

The build system:
1. Looks for the tweak configuration in `tweaks.json`
2. Falls back to sensible defaults if no explicit configuration exists
3. Looks for the `Name:` field in the tweak's control file to determine the output name
4. Uses the dylib name from the Makefile or Package ID
5. Automatically copies files from the tweak's directory to build

## Adding a New Tweak

To add a new tweak:

1. Create a new directory for your tweak (e.g., `BHSnapchat/`)
2. Add the appropriate files (Tweak.x, control, Makefile, etc.) to the directory
3. Add an entry to `tweaks.json`:

```json
"BHSnapchat": {
  "app_url": "https://example.com/snapchat.ipa",
  "app_package": "com.snapchat.app",
  "app_name": "Snapchat",
  "min_ios_version": "15.0"
}
```

If you don't add an entry to `tweaks.json`, the build system will attempt to create reasonable defaults based on naming conventions, but you'll need to provide the app URL manually.

## Auto-discovery

The build system can automatically discover and build tweaks without an explicit entry in `tweaks.json`, with some limitations:

1. The directory must start with "BH" (e.g., BHSnapchat)
2. You'll need to manually specify the app URL since it cannot be auto-detected
3. The system will infer app names and identifiers based on directory names

## Tweak Requirements

Each tweak directory must contain:

1. `control` file with package metadata (including `Name:` field)
2. `Makefile` for building the tweak 
3. `Tweak.x` (or similar) containing the main code

## Development Notes

- The build system will look for tweak dylibs in both the root `.theos` directory and in the tweak's directory
- You can add tweak-specific dependencies in the tweak's Makefile
- Shared modules can be placed in the `modules/` directory
- The output IPA/package will use the name from the `Name:` field in the control file
- Legacy tweaks can be marked with `"legacy": true` in tweaks.json to use special build handling 