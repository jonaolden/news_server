#!/bin/bash

# Exit codes:
# 0 - Success, the service is healthy
# 1 - Failure, the service has issues

# Function for logging with timestamps
log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message"
}

log "INFO" "Running healthcheck"

# Check if calibre-server process is running
if ! pgrep -f "calibre-server" > /dev/null; then
    log "ERROR" "Calibre server process is not running"
    exit 1
fi

# Check if cron is running
if ! pgrep cron > /dev/null; then
    log "WARNING" "Cron service is not running"
    # Not fatal but worth noting
fi

# Check if we can access the server
if ! curl -s --connect-timeout 5 --max-time 10 -I http://localhost:8080/ | grep -q "200 OK"; then
    log "ERROR" "Cannot connect to calibre-server on port 8080"
    exit 1
fi

# Check if library folder is readable
LIBRARY_FOLDER="${LIBRARY_FOLDER:-/opt/library}"
if [ ! -r "$LIBRARY_FOLDER" ]; then
    log "ERROR" "Cannot read from library folder $LIBRARY_FOLDER"
    exit 1
fi

# Check if recipe folder is readable
RECIPES_FOLDER="${RECIPES_FOLDER:-/opt/recipes}"
if [ ! -r "$RECIPES_FOLDER" ]; then
    log "ERROR" "Cannot read from recipes folder $RECIPES_FOLDER"
    exit 1
fi

# Check if there are any recipe files
recipe_count=$(find "$RECIPES_FOLDER" -name "*.recipe" | wc -l)
if [ "$recipe_count" -eq 0 ]; then
    log "WARNING" "No recipe files found in $RECIPES_FOLDER"
    # Not fatal but might indicate an issue
fi

# All checks passed
log "INFO" "Healthcheck passed - service is running properly"
exit 0
