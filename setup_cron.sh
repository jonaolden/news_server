#!/bin/bash

# Exit on error
set -e 
set -o pipefail

# Default cron time if not set
CRON_TIME="${CRON_TIME:-0 0 * * *}"
LOG_DIR="${LOG_DIR:-/var/log/news_server}"
LOG_FILE="${LOG_DIR}/news_download.log"

# Function for logging with timestamps
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

log "INFO" "Setting up cron job with schedule: $CRON_TIME"

# Ensure log directory exists
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR"
    chown calibre:calibre "$LOG_DIR"
    log "INFO" "Created log directory: $LOG_DIR"
fi

# Create a proper cron environment file that includes the necessary environment variables
ENV_FILE="/etc/cron.d/news_server_env"
env | grep -E "^(LIBRARY_FOLDER|RECIPES_FOLDER|USER_DB|CALIBRE_USER|CALIBRE_PASSWORD|LOG_DIR|GITHUB_REPO_URL|DUPLICATE_STRATEGY)" > "$ENV_FILE"
log "INFO" "Created cron environment file: $ENV_FILE"

# Write out crontab with proper environment sourcing
CRON_FILE="/etc/cron.d/news_server"
cat > "$CRON_FILE" << EOF
# News download cron job
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
# Load environment variables
$CRON_TIME calibre bash -c "source $ENV_FILE && /opt/download_news.sh >> $LOG_FILE 2>&1"

# Weekly duplicate cleanup - run every Sunday at 1am
0 1 * * 0 calibre bash -c "source $ENV_FILE && /opt/cleanup_duplicates.sh >> $LOG_FILE 2>&1"
EOF

# Make sure the cron file has the right permissions
chmod 0644 "$CRON_FILE"
log "INFO" "Created cron job at: $CRON_FILE"

# Validate the cron syntax
if ! crontab -u calibre "$CRON_FILE" 2>/dev/null; then
    log "WARNING" "Crontab syntax validation failed. Check your CRON_TIME variable."
    # Continue anyway, but with a default safe cron time
    echo "0 0 * * * calibre bash -c \"source $ENV_FILE && /opt/download_news.sh >> $LOG_FILE 2>&1\"" > "$CRON_FILE"
    chmod 0644 "$CRON_FILE"
    crontab -u calibre "$CRON_FILE"
    log "INFO" "Applied default daily cron schedule as fallback"
fi

# Display the active cron jobs
log "INFO" "Current cron configuration:"
crontab -u calibre -l || log "WARNING" "Could not display crontab"

# Start cron in the background
log "INFO" "Starting cron service"
service cron start || {
    log "WARNING" "Failed to start cron service via service command, trying direct method"
    cron -f &
}

log "INFO" "Cron setup completed successfully"
