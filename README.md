# News Server

A Docker-based solution for automatically downloading news content using Calibre recipes, storing them in a Calibre library, and serving them via a web interface. Ideal for creating your personal news archive.

## Features

- **Automated News Downloads**: Schedule news collection via cron
- **Multiple News Sources**: Supports any site with a Calibre recipe
- **Web Interface**: Access your news via Calibre's web server
- **Recipe Management**: Optionally pull recipes from a Git repository
- **Duplicate Management**: Automatically handles duplicate publications
- **Docker-based**: Easy deployment on any platform supporting Docker
- **Persistent Storage**: Keeps your news library safe between container updates

## Quick Start

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) and [Docker Compose](https://docs.docker.com/compose/install/)
- Basic understanding of environment variables and Docker concepts

### Setup

1. **Clone this repository**:

```bash
git clone https://github.com/jonaolden/news_server.git
cd news_server
```

2. **Configure Environment**:

Create a `.env` file based on the example:

```bash
cp .env.example .env
```

Edit the `.env` file to customize settings:

```bash
# Set your preferred cron schedule 
CRON_TIME="0 0 * * *"  # Daily at midnight

# Set secure credentials
CALIBRE_USER="admin"
CALIBRE_PASSWORD="your_secure_password"

# Optional: Set repository for recipes 
GITHUB_REPO_URL="https://github.com/username/my-recipes.git"
```

3. **Run the Container**:

```bash
docker-compose up -d
```

4. **Access Your News**:

Open your browser and navigate to [http://localhost:8080](http://localhost:8080)

Login with the username/password you specified in the `.env` file.

## Recipe Management

### Adding Recipe Files

Recipe files should be placed in the `recipes` folder with a `.recipe` extension. The file name (without extension) will be used as the publication name in the library.

For example, a recipe file named `economist.recipe` will create a publication titled `economist - YYYY.MM.DD` in the library, where the date represents when the publication was downloaded.

### Using Git for Recipe Management

If you provide a `GITHUB_REPO_URL` in your `.env` file, the container will:
- On first run: Clone the repository into the recipes folder
- On subsequent runs: Pull the latest changes

This allows you to manage recipes in a separate repository and have them automatically updated in your news server.

## Managing the Library

### Duplicates

By default, older versions of a publication are automatically removed when new versions are downloaded. This keeps your library clean.

If you have existing duplicates in your library, you can run the included cleanup script:

```bash
docker-compose exec calibre-server /bin/bash -c "bash /opt/cleanup_duplicates.sh"
```

### Manually Triggering Downloads

To manually trigger a news download:

```bash
docker-compose exec calibre-server /bin/bash -c "su - calibre -c 'bash /opt/download_news.sh'"
```

## Customization

### Custom Recipes

To create your own recipes, see [Calibre's recipe creation guide](https://manual.calibre-ebook.com/news.html).

### Changing Download Schedule

Modify the `CRON_TIME` value in your `.env` file. The format is:

```
minute hour day-of-month month day-of-week
```

For example:
- `0 */6 * * *`: Every 6 hours
- `0 8 * * 1-5`: Weekdays at 8am
- `0 8,18 * * *`: Daily at 8am and 6pm

After changing, restart your container:

```bash
docker-compose restart
```

## Troubleshooting

### Viewing Logs

To view logs:

```bash
docker-compose logs -f
```

Detailed logs are also stored in `/var/log/news_server/` inside the container and available in the `logs` directory on the host.

### Common Issues

- **No publications showing up**: Check if your recipes are valid and in the correct location
- **Permission errors**: Check the ownership of mounted volumes
- **Cron not running**: Check if your cron schedule is valid

## Advanced Configuration

See the `.env.example` file for all available configuration options with descriptions.

## Future Development

The following features are planned for future releases:

### Web UI for Recipe Management
- Graphical interface for managing recipes without command line
- Browse and select recipes from multiple GitHub repositories
- Enable/disable specific recipes
- Edit recipe configurations through the UI
- View download history and logs
- For more details, see [Issue #1](https://github.com/jonaolden/news_server/issues/1)

### Enhanced Scheduling
- Per-recipe scheduling (different download frequencies for different sources)
- More flexible retention policies
- Email notifications for download failures

### Library Management
- Automated categorization of publications
- Better search and filtering options
- Integration with other e-reading platforms

These planned features aim to make the news server more user-friendly and powerful while maintaining its simplicity for basic usage.

## Testing

To test your setup after making changes:

1. Restart the container:
   ```bash
   docker-compose down && docker-compose up -d
   ```

2. Check logs for any errors:
   ```bash
   docker-compose logs -f
   ```

3. Run a manual download to verify recipe processing:
   ```bash
   docker-compose exec calibre-server /bin/bash -c "su - calibre -c 'bash /opt/download_news.sh'"
   ```

4. Access the web interface to confirm publications appear in the library

## License

This project is open source and available under the MIT License.
