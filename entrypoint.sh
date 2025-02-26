#!/bin/bash

# Set environment variables in the shell for subsequent scripts
export LIBRARY_FOLDER="${LIBRARY_FOLDER:-/opt/library}"
export RECIPES_FOLDER="${RECIPES_FOLDER:-/opt/recipes}"
export USER_DB="${USER_DB:-/opt/users.sqlite}"
export CALIBRE_USER="${CALIBRE_USER:-admin}"
export CALIBRE_PASSWORD="${CALIBRE_PASSWORD:-admin}"

echo "Using library folder: $LIBRARY_FOLDER"
echo "Using recipes folder: $RECIPES_FOLDER"

# Fix permissions on mounted volumes
# This ensures calibre user can write to these directories
chown -R calibre:calibre "$LIBRARY_FOLDER" "$RECIPES_FOLDER" "$USER_DB"
chmod -R 755 "$LIBRARY_FOLDER" "$RECIPES_FOLDER"

# 1. Setup cron to use the environment variables
bash /opt/setup_cron.sh

# 2. Run an immediate news download to populate library
# Execute as calibre user
su - calibre -c "bash /opt/download_news.sh"

# 3. Start calibre-server as calibre user
su - calibre -c "calibre-server '$LIBRARY_FOLDER' \
  --enable-auth \
  --userdb '$USER_DB' \
  --username='$CALIBRE_USER' \
  --password='$CALIBRE_PASSWORD'"
