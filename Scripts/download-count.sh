#!/usr/bin/env -S pkgx +gh +jq bash -eo pipefail

# Repository to analyze
REPO="teaxyz/teaBASE"

# Fetch release data using the GitHub CLI
echo "Fetching release data for $REPO..."
releases=$(gh api -H "Accept: application/vnd.github+json" /repos/$REPO/releases)

# Extract download counts from each asset and sum them up
total_downloads=$(echo "$releases" | jq '[.[] | .assets[].download_count] | add')

echo "Total downloads for all releases: $total_downloads"
