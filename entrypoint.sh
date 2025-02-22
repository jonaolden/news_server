#!/bin/bash

# 1. Setup cron to use the environment variables
bash /opt/setup_cron.sh

# 2. Run an immediate news download to populate library
bash /opt/download_news.sh "${LIBRARY_FOLDER}"

# 3. Start calibre-server
calibre-server   "${LIBRARY_FOLDER}"   --enable-auth   --userdb "${USER_DB}"   --username="${CALIBRE_USER}"   --password="${CALIBRE_PASSWORD}"
