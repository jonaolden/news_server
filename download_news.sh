#!/bin/bash

# This script is run by cron or manually.

# Pull the environment variables we need.
LIBRARY_PATH="${LIBRARY_FOLDER:-/opt/library}"
RECIPES_PATH="${RECIPES_FOLDER:-/opt/recipes}"
CALIBRE_USER="${CALIBRE_USER:-admin}"
CALIBRE_PASSWORD="${CALIBRE_PASSWORD:-admin}"
DUP_STRATEGY="${DUPLICATE_STRATEGY:-new_record}"
REPO_URL="${GITHUB_REPO_URL}"

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

    echo "Converting recipe $filename to MOBI $filename.mobi"
    ebook-convert "$filename" "$filename.mobi" --output-profile=kindle

    echo "Annotating MOBI $filename.mobi with 'dailynews' tag"
    ebook-meta "$filename.mobi" --tag "dailynews"

    echo "Adding MOBI $filename.mobi to the library at $LIBRARY_PATH"
    calibredb add "$filename.mobi"         --library-path "$1"         --username "$CALIBRE_USER"         --password "$CALIBRE_PASSWORD"         --automerge "$DUP_STRATEGY"
done

# 3. Clean up leftover epub files, if any
rm -f $RECIPES_PATH/*.epub
