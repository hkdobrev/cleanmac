#!/usr/bin/env bash
set -e

echo "Requesting sudo permissions..."
sudo -v

echo "Starting macOS selective cleanup..."

echo "Clearing system and user cache files older than 7 days..."
sudo find /Library/Caches/* -type f -mtime +7 \( ! -path "/Library/Caches/com.apple.amsengagementd.classicdatavault" \
                                               ! -path "/Library/Caches/com.apple.aned" \
                                               ! -path "/Library/Caches/com.apple.aneuserd" \
                                               ! -path "/Library/Caches/com.apple.iconservices.store" \) \
    -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted files in system cache."

find ~/Library/Caches/* -type f -mtime +7 -exec rm {} \; -print || echo "Error clearing user cache."

echo "Removing application logs older than 7 days..."
sudo find /Library/Logs -type f -mtime +7 -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted files in system logs."
find ~/Library/Logs -type f -mtime +7 -exec rm {} \; -print || echo "Error clearing user logs."

# Clear Temporary Files (Only files older than 7 days), excluding restricted files in /tmp
echo "Clearing temporary files older than 7 days..."
sudo find /private/var/tmp/* -type f -mtime +7 -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted files in system tmp."
find /tmp/* -type f -mtime +7 ! -path "/tmp/tmp-mount-*" -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted tmp files."

echo "Running Homebrew cleanup and cache clearing..."
brew cleanup --prune=7 || echo "Homebrew cleanup encountered an error."
brew autoremove || echo "Homebrew autoremove encountered an error."
brew doctor || echo "Homebrew doctor encountered an error."

echo "Emptying Trash..."
rm -rf ~/.Trash/* || echo "Error emptying Trash."

echo "Selective cleanup complete!"
