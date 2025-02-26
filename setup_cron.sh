#!/bin/bash

# Rebuild the crontab using $CRON_TIME from environment
echo "Setting up cron job with schedule: $CRON_TIME"

# Write out current crontab, append new job, then load it
crontab -l 2>/dev/null | grep -v "download_news.sh" > /tmp/current_cron

# Add the new line - no need to pass URL parameter since we're running locally
echo "$CRON_TIME bash /opt/download_news.sh" >> /tmp/current_cron

crontab /tmp/current_cron
cat /tmp/current_cron

# Start cron in the background
cron
