#!/bin/bash

# Rebuild the crontab using $CRON_TIME from environment
# The calibre server is usually started on port 8080, but you can parametrize

echo "Setting up cron job with schedule: $CRON_TIME"

# Write out current crontab, append new job, then load it
crontab -l 2>/dev/null | grep -v "download_news.sh" > /tmp/current_cron

# Add the new line:
echo "$CRON_TIME bash /opt/download_news.sh 'http://127.0.0.1:8080'" >> /tmp/current_cron

crontab /tmp/current_cron

# Start cron in the background
cron
