# Dockerfile

# Use a specific Debian version for better stability
FROM debian:bullseye-slim

# Set up non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# Set environment variables for paths
ENV LIBRARY_FOLDER=/opt/library
ENV RECIPES_FOLDER=/opt/recipes
ENV USER_DB=/opt/users.sqlite
ENV LOG_DIR=/var/log/news_server

# Install packages (including git, python dependencies for recipes, and health checking tools)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        calibre \
        wget \
        cron \
        git \
        python3-pip \
        curl \
        ca-certificates \
        procps \
        tzdata && \
    pip3 install --no-cache-dir beautifulsoup4 lxml && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create needed folders with proper permissions
RUN mkdir -p $LIBRARY_FOLDER $RECIPES_FOLDER $LOG_DIR /opt/example && \
    chmod 755 $LIBRARY_FOLDER $RECIPES_FOLDER $LOG_DIR

# Copy in scripts first (for better layer caching)
COPY entrypoint.sh /entrypoint.sh
COPY download_news.sh /opt/download_news.sh
COPY cleanup_duplicates.sh /opt/cleanup_duplicates.sh
COPY setup_cron.sh /opt/setup_cron.sh
COPY healthcheck.sh /opt/healthcheck.sh
RUN chmod +x /entrypoint.sh /opt/download_news.sh /opt/cleanup_duplicates.sh /opt/setup_cron.sh /opt/healthcheck.sh

# Install a dummy book to initialize library
RUN wget --no-verbose https://www.gutenberg.org/ebooks/100.kf8.images -O /opt/example/example.mobi && \
    calibredb add /opt/example/* --with-library $LIBRARY_FOLDER && \
    calibredb remove 1 --with-library $LIBRARY_FOLDER && \
    rm -rf /opt/example

# Copy recipes and user database
COPY recipes/ $RECIPES_FOLDER/
COPY users.sqlite $USER_DB

# Create a non-root user for better security and set up a proper home directory
RUN groupadd -r calibre && \
    useradd -r -g calibre -m -d /home/calibre calibre && \
    mkdir -p /home/calibre/.config/calibre && \
    chown -R calibre:calibre $LIBRARY_FOLDER $RECIPES_FOLDER $USER_DB /home/calibre $LOG_DIR && \
    chmod -R 755 $LIBRARY_FOLDER $RECIPES_FOLDER $LOG_DIR

# Set proper timezone handling
ENV TZ=UTC

# Expose the calibre-server port
EXPOSE 8080

# Add a health check to verify the service is running
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
  CMD ["/opt/healthcheck.sh"]

# Default entrypoint
ENTRYPOINT ["/entrypoint.sh"]
