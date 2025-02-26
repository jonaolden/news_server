# Dockerfile

# Pull a specific Ubuntu base image version for better reproducibility
FROM --platform=linux/arm64 ubuntu:22.04

# Set up non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# Set environment variables for paths
ENV LIBRARY_FOLDER=/opt/library
ENV RECIPES_FOLDER=/opt/recipes
ENV USER_DB=/opt/users.sqlite

# Install packages (including git and python dependencies for recipes)
RUN apt-get update && \
    apt-get install -y calibre=5.* wget cron git python3-pip curl && \
    pip3 install beautifulsoup4 lxml && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Create needed folders
RUN mkdir -p $LIBRARY_FOLDER $RECIPES_FOLDER /opt/example

# Copy in scripts first (for better layer caching)
COPY entrypoint.sh /entrypoint.sh
COPY download_news.sh /opt/download_news.sh
COPY setup_cron.sh /opt/setup_cron.sh
RUN chmod +x /entrypoint.sh /opt/download_news.sh /opt/setup_cron.sh

# Install a dummy book to initialize library
RUN wget https://www.gutenberg.org/ebooks/100.kf8.images -O /opt/example/example.mobi && \
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
    chown -R calibre:calibre $LIBRARY_FOLDER $RECIPES_FOLDER $USER_DB /home/calibre && \
    chmod -R 755 $LIBRARY_FOLDER $RECIPES_FOLDER

# Expose the calibre-server port
EXPOSE 8080

# Add a health check to verify the service is running
HEALTHCHECK --interval=30s --timeout=5s \
  CMD curl -f http://localhost:8080/ || exit 1

# Default entrypoint
ENTRYPOINT ["/entrypoint.sh"]
