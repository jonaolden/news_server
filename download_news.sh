#!/bin/bash

# This script removes duplicate publications in the Calibre library,
# keeping only the newest version of each publication.

set -e  # Exit on any error
set -o pipefail  # Pipe fails if any command fails

# Use environment variables if available, otherwise use defaults
LIBRARY_PATH="${LIBRARY_FOLDER:-/opt/library}"

echo "[INFO] Using library path: $LIBRARY_PATH"

# Check if the library is accessible
if [ ! -d "$LIBRARY_PATH" ]; then
    echo "[ERROR] Library path $LIBRARY_PATH does not exist"
    exit 1
fi

# Get a list of all publication base names (without numbering)
echo "[INFO] Finding duplicate publications..."
# List all books and extract titles with their IDs
book_list=$(calibredb list --with-library="$LIBRARY_PATH" --fields="id,title" | tail -n +2)

# Extract base names by removing trailing patterns like " (1)", " (2)", etc.
echo "$book_list" | while read -r line; do
    # Extract ID and full title
    id=$(echo "$line" | awk '{print $1}')
    title=$(echo "$line" | cut -d ' ' -f 2-)
    
    # Extract base name by removing trailing pattern like " (1)", " (2)", etc.
    base_title=$(echo "$title" | sed -E 's/ \([0-9]+\)$//')
    
    # Output ID, full title, and base title for processing
    echo "$id|$title|$base_title"
done > /tmp/book_data.txt

# Process the data to identify duplicates
echo "[INFO] Processing duplicates..."
cat /tmp/book_data.txt | awk -F'|' '{print $3}' | sort | uniq > /tmp/unique_base_titles.txt

# For each base title, find all occurrences and keep only the newest one
while read -r base_title; do
    # Skip empty lines
    [ -z "$base_title" ] && continue
    
    echo "[INFO] Processing duplicates of: $base_title"
    
    # Find all IDs for this base title
    grep "|$base_title\$" /tmp/book_data.txt | grep -v "|$base_title|$base_title\$" > /tmp/matches.txt
    grep "|$base_title|$base_title\$" /tmp/book_data.txt >> /tmp/matches.txt
    
    # If there's only one or no matches, continue to next base title
    match_count=$(wc -l < /tmp/matches.txt)
    if [ "$match_count" -le 1 ]; then
        echo "[INFO] No duplicates found for: $base_title"
        continue
    fi
    
    # Sort by ID in descending order and keep only the first one (newest)
    cat /tmp/matches.txt | sort -t'|' -k1,1nr > /tmp/sorted_matches.txt
    
    # Extract the newest ID (first in sorted list)
    newest_id=$(head -1 /tmp/sorted_matches.txt | cut -d'|' -f1)
    newest_title=$(head -1 /tmp/sorted_matches.txt | cut -d'|' -f2)
    
    echo "[INFO] Keeping newest version: $newest_id - $newest_title"
    
    # Get IDs to remove (all except the newest)
    tail -n +2 /tmp/sorted_matches.txt | cut -d'|' -f1 > /tmp/ids_to_remove.txt
    
    # Remove duplicates
    while read -r id_to_remove; do
        title_to_remove=$(grep "^$id_to_remove|" /tmp/book_data.txt | cut -d'|' -f2)
        echo "[INFO] Removing duplicate: $id_to_remove - $title_to_remove"
        # Use --permanent flag to bypass the recycle bin
        calibredb remove --with-library="$LIBRARY_PATH" --permanent "$id_to_remove" || echo "[WARNING] Failed to remove book ID $id_to_remove"
    done < /tmp/ids_to_remove.txt
done < /tmp/unique_base_titles.txt

# Clean up temporary files
rm -f /tmp/book_data.txt /tmp/unique_base_titles.txt /tmp/matches.txt /tmp/sorted_matches.txt /tmp/ids_to_remove.txt

echo "[INFO] Duplicate cleanup completed successfully!"
