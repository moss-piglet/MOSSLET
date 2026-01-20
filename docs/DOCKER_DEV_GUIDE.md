# Docker Development Guide

This guide covers using Docker Compose for local development of Mosslet.

## Quick Start

```bash
# Start everything (Postgres + Web + Native)
docker compose up

# Or start specific services
docker compose up db          # Just Postgres
docker compose up db web      # Postgres + Web app
docker compose up native      # Native app (SQLite)
```

## Services

| Service | Port | Database | Description |
|---------|------|----------|-------------|
| `db` | 5433 | - | PostgreSQL 16 |
| `web` | 4000 | Postgres | Web version (like production) |
| `native` | 4001 | SQLite | Native/desktop version |

## Common Commands

### Starting Services

```bash
# Start all in foreground (see logs)
docker compose up

# Start all in background
docker compose up -d

# Start specific service(s)
docker compose up db web
```

### Stopping Services

```bash
# Stop all services
docker compose down

# Stop and remove volumes (fresh start)
docker compose down -v
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f web
docker compose logs -f native
```

### Running Commands

```bash
# Run mix commands in web container
docker compose exec web mix ecto.migrate
docker compose exec web mix test

# Open IEx shell
docker compose exec web iex -S mix

# Run in native container
docker compose exec native mix ecto.migrate
```

### Rebuilding

```bash
# Rebuild after Dockerfile.dev changes
docker compose build

# Rebuild and start
docker compose up --build
```

## Development Workflows

### Workflow 1: Full Docker (Cross-Platform Testing)

Best for testing web and native side-by-side:

```bash
docker compose up
# Web at http://localhost:4000
# Native at http://localhost:4001
```

### Workflow 2: Docker Postgres + Local Phoenix (Recommended for Daily Dev)

Best for Tidewave/AI assistant support and faster iteration:

```bash
# Terminal 1: Start just Postgres
docker compose up db -d

# Terminal 2: Run Phoenix locally
PGPORT=5433 iex -S mix phx.server
```

Or update your local `.env` to use port 5433 permanently.

### Workflow 3: Native-Only Testing

```bash
docker compose up native
# Native app at http://localhost:4001 (uses SQLite)
```

## Environment Variables

Copy the example file to configure optional services:

```bash
cp .env.docker.example .env
```

Edit `.env` to add:
- `SECRET_KEY_BASE` - Session encryption
- `AWS_*` - File uploads (Tigris/S3)
- `STRIPE_*` - Billing features
- `SERVER_PUBLIC_KEY` / `SERVER_PRIVATE_KEY` - E2E encryption

Without these, the app runs but some features are disabled.

## Troubleshooting

### Port Already in Use

```bash
# Check what's using port 4000
lsof -i :4000

# Use different ports
PORT=4002 docker compose up web
```

### Database Connection Issues

```bash
# Check if Postgres is healthy
docker compose ps

# View Postgres logs
docker compose logs db

# Reset database
docker compose down -v
docker compose up db
```

### Stale Dependencies

```bash
# Clear deps and rebuild
docker compose down -v
docker compose build --no-cache
docker compose up
```

### Container Won't Start

```bash
# Check logs for errors
docker compose logs web

# Common fixes:
docker compose down -v          # Reset volumes
docker compose build --no-cache # Rebuild image
```

### Native Service Fails

The native service requires `MOSSLET_NATIVE=true` which is set in docker-compose.yml. If you see errors about missing modules:

```bash
# Ensure you have the lib_native directory
ls lib_native/

# Rebuild with native deps
docker compose build native
```

### File Permission Issues (Linux)

```bash
# Fix ownership
sudo chown -R $USER:$USER .

# Or run Docker as current user
DOCKER_USER=$(id -u):$(id -g) docker compose up
```

## Volumes

Docker Compose uses named volumes to persist data and speed up builds:

| Volume | Purpose |
|--------|---------|
| `postgres_data` | Database files |
| `web_deps` / `native_deps` | Elixir dependencies |
| `web_build` / `native_build` | Compiled code |
| `*_assets_node_modules` | Node.js packages |
| `native_data` | SQLite database |

To start completely fresh:

```bash
docker compose down -v
```

## Production Note

This Docker setup is for **development only**. Production deploys to Fly.io using:
- `Dockerfile` (production build)
- `fly.toml` (Fly.io config)

These files are unchanged and separate from the dev Docker setup.
