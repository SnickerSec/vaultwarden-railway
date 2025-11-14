# Vaultwarden Backup Monitoring Dashboard

A beautiful, responsive web dashboard for monitoring and managing Vaultwarden database backups.

## Features

✨ **Real-time Monitoring**
- System status at a glance
- Backup count and storage size
- Latest backup information
- Dependency verification (Railway CLI, PostgreSQL)

🔄 **Backup Management**
- Create backups with one click
- List all available backups
- Verify backup integrity
- View backup details (size, age, permissions)

↻ **Restore Operations**
- Point-and-click restore
- Pre-restore safety backups
- Confirmation dialogs
- Real-time progress

📊 **Log Viewer**
- Recent restore logs
- Verification logs
- Log preview and download

🔒 **Secure**
- Password-protected operations
- Hashed credentials
- Session management
- Path traversal protection

📱 **Responsive Design**
- Works on desktop and mobile
- Dark theme
- Modern UI

## Quick Start

### 1. Setup

```bash
cd monitor
./setup.sh
```

This will:
- Create a Python virtual environment
- Install Flask and dependencies
- Generate secure configuration
- Prompt you to set an admin password

### 2. Run

```bash
source venv/bin/activate
python app.py
```

### 3. Access

Open your browser to: **http://localhost:5000**

## Configuration

Edit `.env` file (created by setup.sh):

```bash
# Admin password hash
MONITOR_PASSWORD_HASH=scrypt:32768:8:1$...

# Secret key for sessions
MONITOR_SECRET_KEY=your-secret-key-here

# Server settings
MONITOR_PORT=5000
MONITOR_DEBUG=false

# Directory paths
BACKUP_DIR=../backups
RESTORE_LOG_DIR=../restore-logs
VERIFICATION_LOG_DIR=../verification-logs
SCRIPTS_DIR=../scripts
```

## Changing Admin Password

```bash
# Generate new password hash
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('new-password'))"

# Update MONITOR_PASSWORD_HASH in .env
```

## Docker Deployment

### Build

```bash
docker build -t vaultwarden-monitor .
```

### Run

```bash
docker run -d \
  --name vaultwarden-monitor \
  -p 5000:5000 \
  -v $(pwd)/../backups:/backups \
  -v $(pwd)/../scripts:/scripts \
  -v $(pwd)/../restore-logs:/restore-logs \
  -v $(pwd)/../verification-logs:/verification-logs \
  -e MONITOR_PASSWORD_HASH="your-hash" \
  -e MONITOR_SECRET_KEY="your-secret" \
  vaultwarden-monitor
```

## Railway Deployment

1. Add new service in Railway
2. Set root directory to `/monitor`
3. Add environment variables:
   - `MONITOR_PASSWORD_HASH`
   - `MONITOR_SECRET_KEY`
   - `DATABASE_URL` (reference from Postgres service)
4. Deploy

## API Documentation

See [MONITORING.md](../docs/MONITORING.md) for complete API documentation.

### Quick Examples

```bash
# Get system status
curl http://localhost:5000/api/status

# List backups
curl http://localhost:5000/api/backups

# Create backup
curl -X POST http://localhost:5000/api/backups/create \
  -H "Content-Type: application/json" \
  -d '{"password":"admin"}'

# Verify backup
curl -X POST http://localhost:5000/api/backups/verify \
  -H "Content-Type: application/json" \
  -d '{"backup_path":"/backups/backup.sql.gz"}'

# Restore backup
curl -X POST http://localhost:5000/api/backups/restore \
  -H "Content-Type: application/json" \
  -d '{"password":"admin","backup_path":"/backups/backup.sql.gz","force":true}'
```

## Screenshots

### Main Dashboard
![Dashboard showing system status, backup list, and quick actions]

### Backup Creation
![Modal dialog for creating a new backup with password authentication]

### Restore Interface
![Restore dialog with safety options and warnings]

## Development

### Project Structure

```
monitor/
├── app.py              # Flask backend
├── templates/
│   └── index.html     # Single-page dashboard
├── requirements.txt   # Python dependencies
├── Dockerfile         # Container config
├── setup.sh          # Setup script
├── .env.example      # Example configuration
└── README.md         # This file
```

### Technologies

- **Backend**: Flask (Python)
- **Frontend**: Vanilla JavaScript, CSS3
- **Authentication**: Werkzeug password hashing
- **Integration**: Subprocess calls to bash scripts

### Adding Features

1. Add API endpoint in `app.py`
2. Add frontend function in `templates/index.html`
3. Test locally
4. Update documentation

## Troubleshooting

### Port Already in Use

```bash
# Change port in .env
MONITOR_PORT=5001

# Or set environment variable
export MONITOR_PORT=5001
python app.py
```

### Script Not Found

```bash
# Check scripts directory
ls -la ../scripts/

# Make scripts executable
chmod +x ../scripts/*.sh

# Verify path in .env
echo $SCRIPTS_DIR
```

### Permission Denied

```bash
# Fix script permissions
chmod +x ../scripts/*.sh

# Fix backup directory
chmod 755 ../backups/
```

### Railway CLI Not Found

```bash
# Install Railway CLI
npm install -g @railway/cli

# Login
railway login

# Link project
railway link
```

## Security Notes

⚠️ **Important Security Considerations:**

1. **Never expose to public internet without HTTPS**
2. **Use strong admin password** (12+ characters)
3. **Rotate secret key** periodically
4. **Use reverse proxy** (nginx/caddy) in production
5. **Restrict network access** with firewall rules
6. **Monitor access logs** for suspicious activity
7. **Keep dependencies updated**

## Production Checklist

- [ ] Set strong admin password
- [ ] Generate new secret key
- [ ] Disable debug mode (`MONITOR_DEBUG=false`)
- [ ] Set up HTTPS (reverse proxy)
- [ ] Configure firewall rules
- [ ] Set up monitoring/alerts
- [ ] Regular security updates
- [ ] Backup configuration files

## Performance

- **Memory**: ~50-100 MB
- **CPU**: Minimal (spikes during operations)
- **Startup**: < 5 seconds
- **Response time**: < 100ms (status/list)
- **Backup time**: 10-60 seconds
- **Restore time**: 1-5 minutes

## Support

For issues or questions:

1. Check [MONITORING.md](../docs/MONITORING.md) documentation
2. Review application logs
3. Check GitHub issues
4. Create new issue with details

## License

Part of the Vaultwarden Railway deployment project.

---

**Version**: 1.0.0
**Last Updated**: January 13, 2025
