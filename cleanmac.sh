#!/usr/bin/env bash
set -e

# Default configuration
DRY_RUN=false

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help)
            echo "Usage: $(basename "$0") [OPTIONS] [DAYS]"
            echo "Clean up unnecessary macOS files."
            echo ""
            echo "Options:"
            echo "    -h, --help      Show this help message"
            echo "    -d, --dry-run   Show what would be deleted without deleting"
            echo ""
            echo "Arguments:"
            echo "    DAYS            Number of days of cache to keep (default: 7)"
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            DAYS_TO_KEEP=$1
            shift
            ;;
    esac
done

# Default to 7 days if no argument provided
DAYS_TO_KEEP=${DAYS_TO_KEEP:-7}

echo "Requesting sudo permissions..."
sudo -v

if [ "$DRY_RUN" = true ]; then
    echo "[DRY RUN] Would clean the following locations (files older than ${DAYS_TO_KEEP} days):"
    echo "- System cache files in /Library/Caches/"
    echo "- User cache files in ~/Library/Caches/"
    echo "- System logs in /Library/Logs/"
    echo "- User logs in ~/Library/Logs/"
    echo "- Temporary files in /private/var/tmp/"
    echo "- Temporary files in /tmp/"
    echo "- Files in ~/.Trash/"
    echo "- Safari cache and history older than ${DAYS_TO_KEEP} days"
    echo "- Xcode derived data and archives"
    echo "- Node.js cache (npm, yarn)"
    echo "- Docker unused images and containers"
    echo "- System memory cache and swap"
    
    if command -v brew >/dev/null 2>&1; then
        echo -e "\nHomebrew dry run results:"
        echo "Running: brew cleanup --dry-run --prune=${DAYS_TO_KEEP}"
        brew cleanup --dry-run --prune=${DAYS_TO_KEEP}
        
        echo -e "\nRunning: brew autoremove --dry-run"
        brew autoremove --dry-run
        
        echo -e "\nRunning: brew doctor"
        brew doctor
    else
        echo "Homebrew is not installed, would skip brew cleanup"
    fi
    exit 0
fi

echo "Starting macOS selective cleanup (removing files older than ${DAYS_TO_KEEP} days)..."

echo "Clearing system and user cache files older than ${DAYS_TO_KEEP} days..."
sudo find /Library/Caches/* -type f -mtime +${DAYS_TO_KEEP} \( ! -path "/Library/Caches/com.apple.amsengagementd.classicdatavault" \
                                               ! -path "/Library/Caches/com.apple.aned" \
                                               ! -path "/Library/Caches/com.apple.aneuserd" \
                                               ! -path "/Library/Caches/com.apple.iconservices.store" \) \
    -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted files in system cache."

find ~/Library/Caches/* -type f -mtime +${DAYS_TO_KEEP} -exec sudo rm -f {} \; -print || echo "Error clearing user cache."

echo "Removing application logs older than ${DAYS_TO_KEEP} days..."
sudo find /Library/Logs -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted files in system logs."
find ~/Library/Logs -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print || echo "Error clearing user logs."

# Clear Temporary Files (Only files older than ${DAYS_TO_KEEP} days), excluding restricted files in /tmp
echo "Clearing temporary files older than ${DAYS_TO_KEEP} days..."
sudo find /private/var/tmp/* -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted files in system tmp."
find /tmp/* -type f -mtime +${DAYS_TO_KEEP} ! -path "/tmp/tmp-mount-*" -exec rm {} \; -print 2>/dev/null || echo "Skipped restricted tmp files."

if command -v brew >/dev/null 2>&1; then
    echo "Running Homebrew cleanup and cache clearing..."
    brew cleanup --prune=${DAYS_TO_KEEP} || echo "Homebrew cleanup encountered an error."
    brew autoremove || echo "Homebrew autoremove encountered an error."
    brew doctor || echo "Homebrew doctor encountered an error."
fi

echo "Emptying Trash (files older than ${DAYS_TO_KEEP} days)..."
find ~/.Trash -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print || echo "Error cleaning Trash."
find ~/.Trash -type d -empty -delete 2>/dev/null || echo "Error removing empty Trash directories."

echo "Cleaning Safari caches..."
find ~/Library/Safari/LocalStorage -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print 2>/dev/null || echo "Error cleaning Safari LocalStorage."
find ~/Library/Safari/WebKit/MediaCache -type f -exec rm {} \; -print 2>/dev/null || echo "Error cleaning Safari MediaCache."

echo "Cleaning Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/* || echo "Error cleaning Xcode derived data."
rm -rf ~/Library/Developer/Xcode/Archives/* || echo "Error cleaning Xcode archives."

# Node.js cache cleaning
if command -v npm >/dev/null 2>&1; then
    echo "Cleaning npm cache..."
    npm cache clean --force || echo "Error cleaning npm cache."
fi

if command -v yarn >/dev/null 2>&1; then
    echo "Cleaning yarn cache..."
    yarn cache clean || echo "Error cleaning yarn cache."
fi

# Docker cleanup
if command -v docker >/dev/null 2>&1; then
    echo "Cleaning unused Docker data..."
    docker system prune -f || echo "Error cleaning Docker system."
fi

# System memory cleanup
echo "Purging system memory cache..."
sudo purge || echo "Error purging system memory."

echo "Selective cleanup complete!"
