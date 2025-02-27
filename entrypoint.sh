#!/bin/bash

# Exit on error
set -e
set -o pipefail

# Set environment variables in the shell for subsequent scripts
export LIBRARY_FOLDER="${LIBRARY_FOLDER:-/opt/library}"
export RECIPES_FOLDER="${RECIPES_FOLDER:-/opt/recipes}"
export USER_DB="${USER_DB:-/opt/users.sqlite}"
export CALIBRE_USER="${CALIBRE_USER:-admin}"
export CALIBRE_PASSWORD="${CALIBRE_PASSWORD:-admin}"
export LOG_DIR="${LOG_DIR:-/var/log/news_server}"
export LOG_FILE="${LOG_DIR}/news_download.log"

# Function for logging with timestamps
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

log "INFO" "Starting news server"
log "INFO" "Using library folder: $LIBRARY_FOLDER"
log "INFO" "Using recipes folder: $RECIPES_FOLDER"

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    log "INFO" "Created log directory: $LOG_DIR"
fi

# Fix permissions on mounted volumes
# This ensures calibre user can write to these directories
log "INFO" "Setting permissions on mounted volumes"
chown -R calibre:calibre "$LIBRARY_FOLDER" "$RECIPES_FOLDER" "$USER_DB" "$LOG_DIR"
chmod -R 755 "$LIBRARY_FOLDER" "$RECIPES_FOLDER" "$LOG_DIR"

# Create initial calibre user if not exists
if [ ! -s "$USER_DB" ]; then
    log "INFO" "Creating initial Calibre user: $CALIBRE_USER"
    mkdir -p "$(dirname "$USER_DB")"
    touch "$USER_DB"
    chown calibre:calibre "$USER_DB"
    su - calibre -c "calibre-server --userdb '$USER_DB' --manage-users add '$CALIBRE_USER' '$CALIBRE_PASSWORD' --readonly-user-role=false"
    
    if [ $? -ne 0 ]; then
        log "WARNING" "Failed to create initial user, but continuing anyway"
    fi
fi

# Check if there are any recipe files present
recipe_count=$(find "$RECIPES_FOLDER" -name "*.recipe" | wc -l)
if [ "$recipe_count" -eq 0 ]; then
    log "WARNING" "No recipe files found in $RECIPES_FOLDER"
    
    # Create a sample recipe file if none exists
    if [ ! -f "$RECIPES_FOLDER/sample.recipe" ]; then
        log "INFO" "Creating a sample recipe file"
        cat > "$RECIPES_FOLDER/sample.recipe" << 'EOF'
#!/usr/bin/env python
# A basic recipe for the BBC news website
from calibre.web.feeds.news import BasicNewsRecipe

class BBCNews(BasicNewsRecipe):
    title = 'BBC News'
    __author__ = 'calibre'
    description = 'News from the BBC'
    oldest_article = 2
    max_articles_per_feed = 10
    no_stylesheets = True
    use_embedded_content = False
    encoding = 'utf8'
    publisher = 'BBC'
    category = 'news'
    language = 'en_GB'
    publication_type = 'newsportal'
    
    feeds = [
        ('Top Stories', 'http://feeds.bbci.co.uk/news/rss.xml'),
        ('World', 'http://feeds.bbci.co.uk/news/world/rss.xml'),
        ('UK', 'http://feeds.bbci.co.uk/news/uk/rss.xml'),
        ('Business', 'http://feeds.bbci.co.uk/news/business/rss.xml'),
        ('Technology', 'http://feeds.bbci.co.uk/news/technology/rss.xml'),
    ]
EOF
        chown calibre:calibre "$RECIPES_FOLDER/sample.recipe"
        log "INFO" "Created sample BBC News recipe"
    fi
fi

# 1. Setup cron to use the environment variables
log "INFO" "Setting up cron job"
bash /opt/setup_cron.sh

# 2. Run an immediate news download to populate library
# Execute as calibre user
log "INFO" "Running initial news download"
su - calibre -c "bash /opt/download_news.sh"

# 3. Start calibre-server as calibre user - make sure to use double quotes for variable expansion
# and NO quotes around variables to allow proper expansion
log "INFO" "Starting Calibre server"
su - calibre -c "calibre-server --port=8080 $LIBRARY_FOLDER --enable-auth --userdb $USER_DB"
