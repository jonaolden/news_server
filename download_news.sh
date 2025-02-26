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

    basename=$(basename "$filename" .recipe)
    output_mobi="$RECIPES_PATH/$basename.mobi"
    
    echo "Converting recipe $filename to MOBI $output_mobi"
    # Ensure we have write permission to the output file
    touch "$output_mobi" || { echo "[ERROR] Cannot create $output_mobi - check permissions"; exit 1; }
    
    ebook-convert "$filename" "$output_mobi" --output-profile=kindle || { 
        echo "[ERROR] Conversion failed for $filename";
        continue;  # Try next recipe instead of failing completely
    }

    if [ ! -f "$output_mobi" ]; then
        echo "[ERROR] Conversion produced no output file: $output_mobi"
        continue
    fi

    echo "Annotating MOBI $output_mobi with 'dailynews' tag"
    ebook-meta "$output_mobi" --tag "dailynews" || echo "[WARNING] Failed to add tag to $output_mobi"

    echo "Adding MOBI $output_mobi to the library at $LIBRARY_PATH"
    calibredb add "$output_mobi" \
        --with-library="$LIBRARY_PATH" \
        --username="$CALIBRE_USER" \
        --password="$CALIBRE_PASSWORD" \
        --automerge="$DUP_STRATEGY" || echo "[WARNING] Failed to add $output_mobi to library"
done

# 3. Clean up leftover mobi files to avoid duplicates next time
echo "Cleaning up temporary MOBI files"
find $RECIPES_PATH -name "*.mobi" -delete || echo "[WARNING] Failed to clean up MOBI files"
