#!/usr/bin/env bash
set -e

# Default to 7 days if no argument provided
DAYS_TO_KEEP=${1:-7}

echo "Requesting sudo permissions..."
sudo -v

echo "Starting macOS selective cleanup (removing files older than ${DAYS_TO_KEEP} days)..."

echo "Clearing system and user cache files older than ${DAYS_TO_KEEP} days..."
sudo find /Library/Caches/* -type f -mtime +${DAYS_TO_KEEP} \( ! -path "/Library/Caches/com.apple.amsengagementd.classicdatavault" \
                                               ! -path "/Library/Caches/com.apple.aned" \
                                               ! -path "/Library/Caches/com.apple.aneuserd" \
                                               ! -path "/Library/Caches/com.apple.iconservices.store" \) \
    -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted files in system cache."

find ~/Library/Caches/* -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print || echo "Error clearing user cache."

echo "Removing application logs older than ${DAYS_TO_KEEP} days..."
sudo find /Library/Logs -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted files in system logs."
find ~/Library/Logs -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print || echo "Error clearing user logs."

# Clear Temporary Files (Only files older than ${DAYS_TO_KEEP} days), excluding restricted files in /tmp
echo "Clearing temporary files older than ${DAYS_TO_KEEP} days..."
sudo find /private/var/tmp/* -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted files in system tmp."
find /tmp/* -type f -mtime +${DAYS_TO_KEEP} ! -path "/tmp/tmp-mount-*" -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted tmp files."

echo "Running Homebrew cleanup and cache clearing..."
brew cleanup --prune=${DAYS_TO_KEEP} || echo "Homebrew cleanup encountered an error."
brew autoremove || echo "Homebrew autoremove encountered an error."
brew doctor || echo "Homebrew doctor encountered an error."

echo "Emptying Trash..."
rm -rf ~/.Trash/* || echo "Error emptying Trash."

echo "Selective cleanup complete!"
