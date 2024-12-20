#!/bin/bash

DMG_PATH="$1"
OUTPUT_DIR="$2"
TARGET_FILE="teaBASE.prefPane"

# Create a temporary mount point
TMP_MOUNT=$(mktemp -d)

# Mount the DMG silently
# -nobrowse: Do not show the mounted volume in Finder
# -quiet: Suppress additional output
hdiutil attach "$DMG_PATH" -mountpoint "$TMP_MOUNT" -nobrowse -quiet

# Sync the files from the DMG to the output directory
# -a: Archive mode, preserves symlinks, permissions, timestamps, etc.
# --delete: Delete files in the output directory that no longer exist in the source
rsync -a --delete "$TMP_MOUNT/teaBASE.prefPane/" "$OUTPUT_DIR/"

# Unmount the DMG
# -quiet: Suppress additional output during unmounting
hdiutil detach "$TMP_MOUNT" -quiet

# Clean up the temporary mount point
rmdir "$TMP_MOUNT"
