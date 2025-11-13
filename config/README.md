# Configuration Files

This directory contains configuration files for various deployment scenarios.

## Files

### `.env.example`
Template environment variables for Vaultwarden. Copy this to `.env` for local development:
```bash
cp .env.example ../.env
```

### `docker-compose.yml`
Docker Compose configuration for local development and testing.

### `Dockerfile.oauth2`
Alternative Dockerfile with Google OAuth2 proxy for additional authentication layer.

### `railway-oauth2.toml`
Railway configuration for OAuth2-protected deployment.

## Usage

### For Railway Deployment
The main `Dockerfile` and `railway.toml` in the root directory are used automatically.

### For Local Development
```bash
cp .env.example ../.env
# Edit .env with your settings
cd ..
docker-compose up -d
```

### For OAuth2 Protected Deployment
See [../docs/GOOGLE_AUTH_SETUP.md](../docs/GOOGLE_AUTH_SETUP.md) for instructions on using the OAuth2 configuration.
