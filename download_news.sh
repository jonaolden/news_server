#!/bin/bash
set -e

# Basic paths
LIBRARY_PATH="${LIBRARY_FOLDER:-/opt/library}"
RECIPES_PATH="${RECIPES_FOLDER:-/opt/recipes}"

# Process each recipe
for recipe in "$RECIPES_PATH"/*.recipe; do
    [ -f "$recipe" ] || continue
    
    publication=$(basename "$recipe" .recipe)
    output_epub="/home/calibre/current.epub"
    
    echo "Processing: $recipe"
    if ebook-convert "$recipe" "$output_epub"; then
        calibredb add "$output_epub" --with-library="$LIBRARY_PATH" --duplicates overwrite && \
        echo "Successfully processed $publication"
        rm -f "$output_epub"
    fi
done
