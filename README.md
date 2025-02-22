# Calibre News Server

This project manages a Docker container running a Calibre server that downloads news recipes and imports them as MOBI files. Recipes can be updated on a schedule via cron and optionally pulled from a GitHub repository.

## Quick Start

#1. **Set Up .env**  
Create a file named .env in the repository root. Copy the contents from .env.example (if provided) or create your own, specifying values for the following:

```bash
CRON_TIME="0 6 * * * *"

GITHB_REPO_URL="https://github.com/username/my-recipe-repo.git"

CALIBRE_USER="admin"
CALIBRE_PASSWORD=you_secure_password
```

#2. **Run Docker Compose**

```bash
docker-compose up --build
```

"3# Access the Server"

The Calibre server is exposed on port 8080, so visit [ http://localhost:8080 ] (adjust if you’re running Docker on another host))
.library folder is mounted to /opt/library for data persistence.

- "** Automatic Recipe Updates **"\n    * A cron job runs at the schedule specified in CRON_TIME.\n    * Before converting recipes, it will do a git pull if you have provided a GitHub reposito."
