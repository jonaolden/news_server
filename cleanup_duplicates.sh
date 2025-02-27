#!/bin/bash

# This script removes duplicate publications in the Calibre library,
# keeping only the newest version of each publication.

set -e  # Exit on any error
set -o pipefail  # Pipe fails if any command fails

# Use environment variables if available, otherwise use defaults
LIBRARY_PATH="${LIBRARY_FOLDER:-/opt/library}"
LOG_FILE="${LOG_FILE:-/var/log/cleanup_duplicates.log}"

# Function for logging with timestamps
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

log "INFO" "Starting duplicate cleanup process"
log "INFO" "Using library path: $LIBRARY_PATH"

# Create log directory if it doesn't exist
LOG_DIR=$(dirname "$LOG_FILE")
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || {
        log "ERROR" "Cannot create log directory $LOG_DIR"
        # Continue anyway, logging to stdout
    }
fi

# Check if the library is accessible
if [ ! -d "$LIBRARY_PATH" ]; then
    log "ERROR" "Library path $LIBRARY_PATH does not exist"
    exit 1
fi

if [ ! -r "$LIBRARY_PATH" ]; then
    log "ERROR" "Cannot read from $LIBRARY_PATH - check permissions"
    exit 1
fi

# Create a secure temp directory for our work
TEMP_DIR=$(mktemp -d)
if [ ! -d "$TEMP_DIR" ]; then
    log "ERROR" "Failed to create temporary directory"
    exit 1
fi

# Ensure temp files get cleaned up on exit
cleanup() {
    rm -rf "$TEMP_DIR"
    log "INFO" "Cleaned up temporary files"
}
trap cleanup EXIT

# Get a list of all books in the library
log "INFO" "Retrieving book list from Calibre library"
if ! calibredb list --with-library="$LIBRARY_PATH" --fields="id,title" > "$TEMP_DIR/full_book_list.txt"; then
    log "ERROR" "Failed to retrieve book list from Calibre"
    exit 1
fi

# Skip header line and process each book
tail -n +2 "$TEMP_DIR/full_book_list.txt" | while read -r line; do
    # Extract ID and full title
    id=$(echo "$line" | awk '{print $1}')
    title=$(echo "$line" | cut -d ' ' -f 2-)
    
    # Extract publication name (everything before the date)
    # Assuming format like "Publication - YYYY.MM.DD"
    pub_name=$(echo "$title" | sed -E 's/ - [0-9]{4}\.[0-9]{2}\.[0-9]{2}.*$//')
    
    # Extract date part for sorting
    date_part=$(echo "$title" | grep -o '[0-9]\{4\}\.[0-9]\{2\}\.[0-9]\{2\}' || echo "")
    
    # Only process if we have a valid date format (some books might not follow this pattern)
    if [ ! -z "$date_part" ]; then
        echo "$id|$title|$pub_name|$date_part" >> "$TEMP_DIR/book_data.txt"
    fi
done

# Check if we found any books matching our pattern
if [ ! -f "$TEMP_DIR/book_data.txt" ] || [ ! -s "$TEMP_DIR/book_data.txt" ]; then
    log "INFO" "No books with expected date pattern found in the library"
    exit 0
fi

# Get unique publication names
cut -d'|' -f3 "$TEMP_DIR/book_data.txt" | sort | uniq > "$TEMP_DIR/unique_publications.txt"

# Process each publication to find and remove duplicates
while read -r pub_name; do
    # Skip empty lines
    [ -z "$pub_name" ] && continue
    
    log "INFO" "Processing duplicates for: $pub_name"
    
    # Find all books for this publication and sort by date (newest first)
    grep "^[0-9]*|.*|$pub_name|" "$TEMP_DIR/book_data.txt" | sort -t'|' -k4 -r > "$TEMP_DIR/matched_books.txt"
    
    # Count matches
    match_count=$(wc -l < "$TEMP_DIR/matched_books.txt")
    if [ "$match_count" -le 1 ]; then
        log "INFO" "No duplicates found for: $pub_name (only $match_count copies)"
        continue
    fi
    
    # Get the newest book (first line after sorting)
    newest_book=$(head -1 "$TEMP_DIR/matched_books.txt")
    newest_id=$(echo "$newest_book" | cut -d'|' -f1)
    newest_title=$(echo "$newest_book" | cut -d'|' -f2)
    
    log "INFO" "Keeping newest version: $newest_id - $newest_title"
    
    # Process books to remove (all except the newest)
    tail -n +2 "$TEMP_DIR/matched_books.txt" | while read -r book_to_remove; do
        id_to_remove=$(echo "$book_to_remove" | cut -d'|' -f1)
        title_to_remove=$(echo "$book_to_remove" | cut -d'|' -f2)
        
        log "INFO" "Removing duplicate: $id_to_remove - $title_to_remove"
        
        if ! calibredb remove --with-library="$LIBRARY_PATH" --permanent "$id_to_remove"; then
            log "WARNING" "Failed to remove book ID $id_to_remove"
        fi
    done
    
    # Count how many were removed
    removed_count=$((match_count - 1))
    log "INFO" "Removed $removed_count duplicates of $pub_name"
    
done < "$TEMP_DIR/unique_publications.txt"

log "INFO" "Duplicate cleanup completed successfully"
