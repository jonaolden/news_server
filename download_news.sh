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

echo "[INFO] Using library path: $LIBRARY_PATH"
echo "[INFO] Using recipes path: $RECIPES_PATH"

# Check if directories are writable
if [ ! -w "$RECIPES_PATH" ]; then
    echo "[ERROR] Cannot write to $RECIPES_PATH - check permissions"
    exit 1
fi

if [ ! -w "$LIBRARY_PATH" ]; then
    echo "[ERROR] Cannot write to $LIBRARY_PATH - check permissions"
    exit 1
fi

# Clean up any leftover EPUB files from previous runs first
echo "[INFO] Cleaning up any existing EPUB files before starting"
find $RECIPES_PATH -name "*.epub" -delete || echo "[WARNING] Failed to clean up existing EPUB files"

# 1. If GitHub repository is defined, clone or pull
if [ -n "$REPO_URL" ]; then
    if [ -d "$RECIPES_PATH/.git" ]; then
        echo "[INFO] Found existing git repo in $RECIPES_PATH. Pulling latest..."
        cd $RECIPES_PATH && git pull
    else
        echo "[INFO] Cloning git repo: $REPO_URL into $RECIPES_PATH"
        rm -rf "$RECIPES_PATH"/* # clean out any old non-git files
        git clone "$REPO_URL" "$RECIPES_PATH"
    fi
fi

# 2. Convert recipes and add to library
for filename in $RECIPES_PATH/*.recipe; do
    [ -e "$filename" ] || continue  # Skip if no .recipe files

    # Get the base name (publication name) from the recipe file
    publication=$(basename "$filename" .recipe)
    output_epub="$RECIPES_PATH/$publication.epub"
    
    echo "[INFO] Converting recipe $filename to EPUB $output_epub"
    # Ensure we have write permission to the output file
    touch "$output_epub" || { echo "[ERROR] Cannot create $output_epub - check permissions"; exit 1; }
    
    ebook-convert "$filename" "$output_epub" || { 
        echo "[ERROR] Conversion failed for $filename";
        continue;  # Try next recipe instead of failing completely
    }

    if [ ! -f "$output_epub" ]; then
        echo "[ERROR] Conversion produced no output file: $output_epub"
        continue
    fi

    echo "[INFO] Annotating EPUB $output_epub with 'dailynews' tag"
    ebook-meta "$output_epub" --tag "dailynews" || echo "[WARNING] Failed to add tag to $output_epub"
    
    # Use consistent date-based title format for the publication
    today=$(date +"%Y.%m.%d")
    publication_title="$publication - $today"
    echo "[INFO] Setting publication title to: $publication_title"
    ebook-meta "$output_epub" --title "$publication_title" || echo "[WARNING] Failed to set title for $output_epub"

    # First check for and remove existing entries with the same publication name
    echo "[INFO] Checking for existing entries of $publication in the library"
    # Get list of book IDs that match the publication pattern
    book_ids=$(calibredb list --with-library="$LIBRARY_PATH" --search="title:$publication" --fields="id" | grep -o '[0-9]\+' || echo "")
    
    if [ ! -z "$book_ids" ]; then
        echo "[INFO] Found existing entries for $publication. Removing them before adding new version."
        for book_id in $book_ids; do
            echo "[INFO] Removing book ID $book_id"
            # Use --permanent flag to bypass the recycle bin and avoid home directory errors
            calibredb remove --with-library="$LIBRARY_PATH" --permanent "$book_id" || echo "[WARNING] Failed to remove book ID $book_id"
        done
    fi

    echo "[INFO] Adding EPUB $output_epub to the library at $LIBRARY_PATH"
    calibredb add "$output_epub" \
        --with-library="$LIBRARY_PATH" || echo "[WARNING] Failed to add $output_epub to library"
done

# 3. Clean up leftover epub files to avoid duplicates next time
echo "[INFO] Cleaning up temporary EPUB files"
find $RECIPES_PATH -name "*.epub" -delete || echo "[WARNING] Failed to clean up EPUB files"

echo "[INFO] News download completed successfully"
