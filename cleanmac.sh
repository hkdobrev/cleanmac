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

# Check that the number of days to keep is a positive integer
if ! [[ $DAYS_TO_KEEP =~ ^(0|[1-9][0-9]*)$ ]]; then
    echo "Error: DAYS must be a positive integer."
    exit 1
fi

# Get initial disk space
free_storage=$(df -k / | awk 'NR==2 {print $4}')
total_storage=$(df -k / | awk 'NR==2 {print $2}')
free_storage_gb=$(echo "scale=2; $free_storage / 1024 / 1024" | bc)
total_storage_gb=$(echo "scale=2; $total_storage / 1024 / 1024" | bc)

echo "Free storage: $free_storage_gb Gi / Total storage: $total_storage_gb Gi"

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
    echo "- Safari cache older than ${DAYS_TO_KEEP} days"
    echo "- Spotify cache older than ${DAYS_TO_KEEP} days"
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

echo "Cleaning Spotify cache..."
find ~/Library/Application\ Support/Spotify/PersistentCache/Storage -type f -mtime +${DAYS_TO_KEEP} -exec rm {} \; -print 2>/dev/null || echo "Error cleaning Spotify cache."

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
    echo "Checking Docker context..."
    if ! current_context=$(docker context show 2>/dev/null); then
        echo "Unable to determine Docker context; assuming local and cleaning."
        docker system prune -f || echo "Error cleaning Docker system."
    else
        if endpoint=$(docker context inspect "$current_context" --format '{{.Endpoints.docker.Host}}' 2>/dev/null); then
            if [[ "$endpoint" == unix://* ]]; then
                echo "Cleaning unused Docker data..."
                docker system prune -f || echo "Error cleaning Docker system."
            else
                echo "Docker is using a remote context ($endpoint), skipping cleanup."
            fi
        else
            echo "Unable to inspect Docker context; skipping cleanup to avoid potential remote connection."
        fi
    fi
fi

# System memory cleanup
echo "Purging system memory cache..."
sudo purge || echo "Error purging system memory."

# At the end, before the final message
echo -e "\nAfter cleanup:"

# Get disk space
free_storage_final=$(df -k / | awk 'NR==2 {print $4}')
total_storage_final=$(df -k / | awk 'NR==2 {print $2}')
free_storage_final_gb=$(echo "scale=2; $free_storage_final / 1024 / 1024" | bc)
total_storage_final_gb=$(echo "scale=2; $total_storage_final / 1024 / 1024" | bc)

echo "Free storage: $free_storage_final_gb Gi / Total storage: $total_storage_final_gb Gi"

# Calculate the difference in kilobytes
free_storage_diff_kb=$((free_storage_final - free_storage))

# If the difference is negative, set it to 0
if [ "$free_storage_diff_kb" -lt 0 ]; then
    free_storage_diff_kb=0
fi

# Determine appropriate unit for the difference
if [ "$free_storage_diff_kb" -ge $((1024 * 1024)) ]; then
    # Convert difference to gigabytes if >= 1 Gi
    free_storage_diff_gb=$(echo "scale=2; $free_storage_diff_kb / 1024 / 1024" | bc)
    echo "Space freed: $free_storage_diff_gb Gi"
elif [ "$free_storage_diff_kb" -ge 1024 ]; then
    # Convert difference to megabytes if >= 1 Mi but < 1 Gi
    free_storage_diff_mb=$(echo "scale=2; $free_storage_diff_kb / 1024" | bc)
    echo "Space freed: $free_storage_diff_mb Mi"
else
    # Output difference in kilobytes if < 1 Mi
    echo "Space freed: $free_storage_diff_kb Ki"
fi

echo "Selective cleanup complete!"
