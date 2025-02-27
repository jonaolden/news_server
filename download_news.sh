#!/bin/bash

# This script is run by cron or manually.
set -e  # Exit on any error
set -o pipefail  # Pipe fails if any command fails

# Pull the environment variables we need.
LIBRARY_PATH="${LIBRARY_FOLDER:-/opt/library}"
RECIPES_PATH="${RECIPES_FOLDER:-/opt/recipes}"
CALIBRE_USER="${CALIBRE_USER:-admin}"
CALIBRE_PASSWORD="${CALIBRE_PASSWORD:-admin}"
DUP_STRATEGY="${DUPLICATE_STRATEGY:-new_record}"
REPO_URL="${GITHUB_REPO_URL}"
LOG_FILE="${LOG_FILE:-/var/log/news_download.log}"

# Function for logging with timestamps
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

log "INFO" "Starting news download process"
log "INFO" "Using library path: $LIBRARY_PATH"
log "INFO" "Using recipes path: $RECIPES_PATH"

# Check if directories are writable
if [ ! -w "$RECIPES_PATH" ]; then
    log "ERROR" "Cannot write to $RECIPES_PATH - check permissions"
    exit 1
fi

if [ ! -w "$LIBRARY_PATH" ]; then
    log "ERROR" "Cannot write to $LIBRARY_PATH - check permissions"
    exit 1
fi

# Create log directory if it doesn't exist
LOG_DIR=$(dirname "$LOG_FILE")
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || {
        log "ERROR" "Cannot create log directory $LOG_DIR"
        # Continue anyway, logging to stdout
    }
fi

# Clean up any leftover EPUB files from previous runs first
log "INFO" "Cleaning up any existing EPUB files before starting"
find $RECIPES_PATH -name "*.epub" -delete || log "WARNING" "Failed to clean up existing EPUB files"

# 1. If GitHub repository is defined, clone or pull
if [ -n "$REPO_URL" ]; then
    if [ -d "$RECIPES_PATH/.git" ]; then
        log "INFO" "Found existing git repo in $RECIPES_PATH. Pulling latest..."
        cd $RECIPES_PATH && git pull || log "ERROR" "Failed to pull from git repository"
    else
        log "INFO" "Cloning git repo: $REPO_URL into $RECIPES_PATH"
        # Create a backup of existing recipes before cloning
        BACKUP_DIR="/tmp/recipes_backup_$(date +%Y%m%d%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        cp -r "$RECIPES_PATH"/* "$BACKUP_DIR"/ 2>/dev/null || log "WARNING" "No existing recipes to backup"
        
        # Clean out any old non-git files
        rm -rf "$RECIPES_PATH"/* 
        
        # Clone the repository
        if ! git clone "$REPO_URL" "$RECIPES_PATH"; then
            log "ERROR" "Failed to clone git repository. Restoring backup."
            rm -rf "$RECIPES_PATH"/*
            cp -r "$BACKUP_DIR"/* "$RECIPES_PATH"/ 2>/dev/null
            log "INFO" "Backup restored"
        else
            log "INFO" "Git clone successful"
            rm -rf "$BACKUP_DIR"
        fi
    fi
fi

# Check if we have any recipes
recipe_count=$(find "$RECIPES_PATH" -name "*.recipe" | wc -l)
if [ "$recipe_count" -eq 0 ]; then
    log "WARNING" "No .recipe files found in $RECIPES_PATH. Nothing to download."
    exit 0
fi

# 2. Convert recipes and add to library
for filename in $RECIPES_PATH/*.recipe; do
    [ -e "$filename" ] || continue  # Skip if no .recipe files

    # Get the base name (publication name) from the recipe file
    publication=$(basename "$filename" .recipe)
    output_epub="$RECIPES_PATH/$publication.epub"
    
    log "INFO" "Converting recipe $filename to EPUB $output_epub"
    # Ensure we have write permission to the output file
    touch "$output_epub" || { 
        log "ERROR" "Cannot create $output_epub - check permissions"
        continue # Skip this recipe instead of exiting
    }
    
    # Convert with a reasonable timeout (30 minutes)
    if ! timeout 1800 ebook-convert "$filename" "$output_epub"; then
        log "ERROR" "Conversion failed or timed out for $filename"
        continue  # Try next recipe instead of failing completely
    fi

    if [ ! -f "$output_epub" ]; then
        log "ERROR" "Conversion produced no output file: $output_epub"
        continue
    fi

    log "INFO" "Annotating EPUB $output_epub with 'dailynews' tag"
    ebook-meta "$output_epub" --tag "dailynews" || log "WARNING" "Failed to add tag to $output_epub"
    
    # Use consistent date-based title format for the publication
    today=$(date +"%Y.%m.%d")
    publication_title="$publication - $today"
    log "INFO" "Setting publication title to: $publication_title"
    ebook-meta "$output_epub" --title "$publication_title" || log "WARNING" "Failed to set title for $output_epub"

    # First check for and remove existing entries with the same publication name
    log "INFO" "Checking for existing entries of $publication in the library"
    # Get list of book IDs that match the publication pattern
    book_ids=$(calibredb list --with-library="$LIBRARY_PATH" --search="title:$publication" --fields="id" | grep -o '[0-9]\+' || echo "")
    
    if [ ! -z "$book_ids" ]; then
        log "INFO" "Found existing entries for $publication. Removing them before adding new version."
        for book_id in $book_ids; do
            log "INFO" "Removing book ID $book_id"
            # Use --permanent flag to bypass the recycle bin and avoid home directory errors
            calibredb remove --with-library="$LIBRARY_PATH" --permanent "$book_id" || log "WARNING" "Failed to remove book ID $book_id"
        done
    fi

    log "INFO" "Adding EPUB $output_epub to the library at $LIBRARY_PATH"
    if ! calibredb add "$output_epub" --with-library="$LIBRARY_PATH"; then
        log "ERROR" "Failed to add $output_epub to library"
    else
        log "INFO" "Successfully added $publication_title to library"
    fi
done

# 3. Clean up leftover epub files to avoid duplicates next time
log "INFO" "Cleaning up temporary EPUB files"
find $RECIPES_PATH -name "*.epub" -delete || log "WARNING" "Failed to clean up EPUB files"

log "INFO" "News download completed successfully"
