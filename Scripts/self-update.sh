#!/bin/bash

DMG_PATH="$1"
OUTPUT_DIR="$2"
TARGET_FILE="teaBASE.prefPane"

# Create a temporary mount point
TMP_MOUNT=$(mktemp -d)

# Mount the DMG silently
hdiutil attach "$DMG_PATH" -mountpoint "$TMP_MOUNT" -nobrowse -quiet

#TODO use `ditto`
rsync -a --delete "$TMP_MOUNT/teaBASE.prefPane/" "$OUTPUT_DIR/"

# Unmount the DMG
hdiutil detach "$TMP_MOUNT" -quiet

# Clean up the temporary mount point
rmdir "$TMP_MOUNT"
