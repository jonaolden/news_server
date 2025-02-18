# Dockerfile

# Pull an Ubuntu base image (arm64 example, can remove if you prefer x86)
FROM --platform=linux/arm64 ubuntu:latest

# Set up non-interactive mode for apt
ENV DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NONINTERACTIVE_SEEN=true

# Install packages (including git)
RUN apt-get update &&     apt-get install -y calibre wget cron git &&     apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy in scripts
COPY entrypoint.sh /entrypoint.sh
COPY download_news.sh /opt/download_news.sh
COPY setup_cron.sh /opt/setup_cron.sh
RUN chmod +x /entrypoint.sh /opt/download_news.sh /opt/setup_cron.sh

# Create needed folders (defined in .env but we create them anyway)
ARG LIBRARY_FOLDER=/opt/library
ARG RECIPES_FOLDER=/opt/recipes
ARG EBOOK_EXAMPLE_FOLDER=/opt/example
ARG USER_DB=/opt/users.sqlite

RUN mkdir -p $LIBRARY_FOLDER $RECIPES_FOLDER $EBOOK_EXAMPLE_FOLDER

# Install a dummy book, then remove it to initialize library
RUN wget https://www.gutenberg.org/ebooks/100.kf8.images -O $EBOOK_EXAMPLE_FOLDER/example.mobi &&     calibredb add $EBOOK_EXAMPLE_FOLDER/* --with-library $LIBRARY_FOLDER &&     calibredb remove 1 --with-library $LIBRARY_FOLDER 

# Copy default local user DB (optional if you want it inside container)
COPY users.sqlite $USER_DB

# Expose the calibre-server port
EXPOSE 8080

# Default entrypoint
ENTRYPOINT [
/entrypoint.sh
]
