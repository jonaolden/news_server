# Calibre News Server

This project manages a Docker container running a Calibre server that downloads news recipes and imports them as EPUB files. Recipes can be updated on a schedule via cron and optionally pulled from a GitHub repository.

## Quick Start

1. **Set Up .env**  
Create a file named .env in the repository root. Copy the contents from .env.example (if provided) or create your own, specifying values for the following:

```bash
CRON_TIME="0 6 * * * *"

GITHUB_REPO_URL="https://github.com/username/my-recipe-repo.git"

CALIBRE_USER="admin"
CALIBRE_PASSWORD=your_secure_password
```

2. **Run Docker Compose**

```bash
docker-compose up --build
```

3. **Access the Server**

The Calibre server is exposed on port 8080, so visit [http://localhost:8080](http://localhost:8080) (adjust if you're running Docker on another host)
The library folder is mounted to /opt/library for data persistence.

## Automatic Recipe Updates

* A cron job runs at the schedule specified in CRON_TIME.
* Before converting recipes, it will do a git pull if you have provided a GitHub repository.
* Each news publication is converted to EPUB format with a consistent naming convention.
* Old versions of publications are automatically deleted and replaced with new ones.

## Managing Duplicates

By default, the system is set up to automatically handle duplicates by removing older versions of the same publication before adding new ones. This ensures your library stays clean and organized.

If you have existing duplicates in your library, you can run the included `cleanup_duplicates.sh` script to remove them:

```bash
docker-compose exec calibre-server /bin/bash -c "bash /opt/cleanup_duplicates.sh"
```

## Recipe Files

Recipe files should be placed in the `recipes` folder with a `.recipe` extension. The file name (without extension) will be used as the publication name in the library.

For example, a recipe file named `economist.recipe` will create a publication titled `economist - YYYY.MM.DD` in the library, where the date represents when the publication was downloaded.
