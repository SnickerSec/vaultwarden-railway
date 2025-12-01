# Configuration Files

This directory contains configuration files organized by purpose.

## Directory Structure

```
config/
├── examples/           # Template files and examples
│   └── .env.example    # Environment variables template
├── docker/             # Docker-related configurations
│   └── docker-compose.yml  # Local development setup
├── variants/           # Alternative deployment configurations
│   ├── Dockerfile.oauth2   # OAuth2 proxy Dockerfile
│   └── railway-oauth2.toml # Railway config for OAuth2
└── README.md
```

## Usage

### Environment Variables

Copy the example file to set up your environment:

```bash
cp config/examples/.env.example .env
# Edit .env with your settings
```

### Local Development

Use Docker Compose for local testing:

```bash
cd config/docker
docker-compose up -d
```

### Railway Deployment

The main `Dockerfile` and `railway.toml` in the root directory are used automatically by Railway.

### OAuth2 Protected Deployment

For Google OAuth2 pre-authentication, use the variant configurations:

1. Copy `variants/Dockerfile.oauth2` to root as `Dockerfile`
2. Copy `variants/railway-oauth2.toml` to root as `railway.toml`
3. Configure OAuth2 credentials in Railway variables

See [../docs/GOOGLE_AUTH_SETUP.md](../docs/GOOGLE_AUTH_SETUP.md) for detailed instructions.
