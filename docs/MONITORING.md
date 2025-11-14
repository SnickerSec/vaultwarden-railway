# Vaultwarden Backup Monitoring Dashboard

A comprehensive web-based monitoring dashboard for managing Vaultwarden backups and restores.

## Features

- **Real-time System Status** - Monitor backup health and system requirements
- **Backup Management** - Create, verify, and list all backups
- **One-Click Restore** - Restore from any backup with safety checks
- **Log Viewer** - View recent restore and verification logs
- **Secure Access** - Password-protected operations
- **Responsive Design** - Works on desktop and mobile devices

## Quick Start

### Local Setup

1. **Navigate to the monitor directory:**
   ```bash
   cd monitor
   ```

2. **Run the setup script:**
   ```bash
   ./setup.sh
   ```

   This will:
   - Create a Python virtual environment
   - Install dependencies
   - Generate secure configuration
   - Prompt you to set an admin password

3. **Start the dashboard:**
   ```bash
   source venv/bin/activate
   python app.py
   ```

4. **Open your browser:**
   ```
   http://localhost:5000
   ```

### Docker Setup

1. **Build the Docker image:**
   ```bash
   cd monitor
   docker build -t vaultwarden-monitor .
   ```

2. **Run the container:**
   ```bash
   docker run -d \
     --name vaultwarden-monitor \
     -p 5000:5000 \
     -v $(pwd)/../backups:/backups \
     -v $(pwd)/../scripts:/scripts \
     -v $(pwd)/../restore-logs:/restore-logs \
     -v $(pwd)/../verification-logs:/verification-logs \
     -e MONITOR_PASSWORD_HASH="your-password-hash" \
     -e MONITOR_SECRET_KEY="your-secret-key" \
     vaultwarden-monitor
   ```

3. **Access the dashboard:**
   ```
   http://localhost:5000
   ```

### Railway Deployment

1. **Add a new service to your Railway project:**
   - Go to your Railway project
   - Click "New" → "Empty Service"
   - Name it "vaultwarden-monitor"

2. **Configure the service:**
   - Set root directory to `/monitor`
   - Railway will auto-detect the Dockerfile

3. **Add environment variables:**
   ```
   MONITOR_PASSWORD_HASH=<your-hash>
   MONITOR_SECRET_KEY=<your-secret>
   BACKUP_DIR=/backups
   SCRIPTS_DIR=/scripts
   DATABASE_URL=${{Postgres.DATABASE_URL}}
   ```

4. **Deploy:**
   - Railway will automatically deploy
   - Access via the generated Railway URL

## Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `MONITOR_PASSWORD_HASH` | Hashed admin password | `admin` | Yes |
| `MONITOR_SECRET_KEY` | Session secret key | Random | Yes |
| `MONITOR_PORT` | Server port | `5000` | No |
| `MONITOR_DEBUG` | Debug mode | `false` | No |
| `BACKUP_DIR` | Backup directory path | `../backups` | No |
| `RESTORE_LOG_DIR` | Restore logs path | `../restore-logs` | No |
| `VERIFICATION_LOG_DIR` | Verification logs path | `../verification-logs` | No |
| `SCRIPTS_DIR` | Scripts directory path | `../scripts` | No |

### Generate Password Hash

```bash
# Using Python
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('your-password'))"

# Or using the interactive method
cd monitor
source venv/bin/activate
python
>>> from werkzeug.security import generate_password_hash
>>> generate_password_hash('your-password')
```

### Generate Secret Key

```bash
python -c "import os; print(os.urandom(32).hex())"
```

## Dashboard Overview

### System Status Card

Displays:
- Total number of backups
- Total backup storage size
- Railway CLI installation status
- PostgreSQL client status
- Latest backup information

### Quick Actions

- **Create Backup** - Manually create a new database backup
- **Refresh List** - Reload the backup list

### Backups List

For each backup, you can:
- View size, date, and permissions
- **Verify** - Check backup integrity
- **Restore** - Restore database from backup

### Logs Viewer

View recent:
- Restore operation logs
- Backup verification logs

## Using the Dashboard

### Creating a Backup

1. Click **"Create Backup"** button
2. Enter your admin password
3. Click **"Create Backup"**
4. Wait for completion (usually 10-60 seconds)
5. New backup appears in the list

### Verifying a Backup

1. Find the backup in the list
2. Click **"✓ Verify"** button
3. Wait for verification (5-30 seconds)
4. Alert shows success or failure
5. Check verification logs for details

### Restoring a Backup

1. Find the backup in the list
2. Click **"↻ Restore"** button
3. Review the warning message
4. Enter your admin password
5. Optionally:
   - Check "Skip safety backup" (not recommended)
   - Check "Force restore" (skips confirmations)
6. Click **"Restore Backup"**
7. Confirm the action
8. Wait for restore (1-5 minutes)
9. Check restore logs for details

**Important:**
- Restore operations REPLACE all current data
- A safety backup is created first (unless skipped)
- The database will be briefly unavailable during restore

## API Endpoints

The dashboard exposes a REST API:

### GET `/api/status`
Get system status information

**Response:**
```json
{
  "success": true,
  "data": {
    "timestamp": "2025-01-13T15:30:00",
    "backup_count": 15,
    "total_backup_size": 52428800,
    "total_backup_size_human": "50.00 MB",
    "latest_backup": {...},
    "railway_cli_installed": true,
    "psql_installed": true,
    "scripts_exist": {...}
  }
}
```

### GET `/api/backups`
List all available backups

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "vaultwarden_db_backup_20250113_030000.sql.gz",
      "path": "/backups/vaultwarden_db_backup_20250113_030000.sql.gz",
      "size": 3145728,
      "size_human": "3.00 MB",
      "modified": "2025-01-13T03:00:00",
      "modified_ago": "12 hours ago",
      "permissions": "600"
    }
  ]
}
```

### POST `/api/backups/create`
Create a new backup

**Request:**
```json
{
  "password": "admin-password"
}
```

**Response:**
```json
{
  "success": true,
  "message": "Backup created successfully",
  "output": "..."
}
```

### POST `/api/backups/verify`
Verify a backup file

**Request:**
```json
{
  "backup_path": "/backups/backup.sql.gz"
}
```

**Response:**
```json
{
  "success": true,
  "output": "...",
  "error": ""
}
```

### POST `/api/backups/restore`
Restore from a backup

**Request:**
```json
{
  "password": "admin-password",
  "backup_path": "/backups/backup.sql.gz",
  "skip_backup": false,
  "force": false
}
```

**Response:**
```json
{
  "success": true,
  "message": "Restore completed successfully",
  "output": "..."
}
```

### GET `/api/logs/restore`
Get recent restore logs

**Response:**
```json
{
  "success": true,
  "data": [
    {
      "name": "restore_log_20250113_153000.txt",
      "path": "/restore-logs/restore_log_20250113_153000.txt",
      "size": 2048,
      "size_human": "2.00 KB",
      "modified": "2025-01-13T15:30:00",
      "modified_ago": "5 minutes ago",
      "preview": "..."
    }
  ]
}
```

### GET `/api/logs/verification`
Get recent verification logs

### GET `/health`
Health check endpoint

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2025-01-13T15:30:00"
}
```

## Security Considerations

### Authentication

- All backup/restore operations require password authentication
- Password is hashed using Werkzeug's `scrypt` algorithm
- Sessions are protected with secret keys

### Authorization

- Only authenticated users can create/restore backups
- Read-only operations (status, list) don't require auth
- Log viewing doesn't require auth (logs are on secure server)

### Path Security

- All file paths are validated to prevent directory traversal
- Only files within designated directories can be accessed
- Symlink attacks are prevented

### Best Practices

1. **Use strong admin password**
   - Minimum 12 characters
   - Mix of letters, numbers, symbols
   - Don't use common passwords

2. **Secure the secret key**
   - Generate a random 32-byte key
   - Never commit to version control
   - Rotate periodically

3. **Restrict network access**
   - Use firewall rules
   - Bind to localhost if local-only
   - Use HTTPS in production (reverse proxy)

4. **Monitor access logs**
   - Review application logs regularly
   - Check for unauthorized access attempts
   - Set up alerts for suspicious activity

5. **Keep dependencies updated**
   ```bash
   cd monitor
   source venv/bin/activate
   pip install --upgrade -r requirements.txt
   ```

## Reverse Proxy Setup

For production, use a reverse proxy (nginx, caddy) with HTTPS.

### Nginx Example

```nginx
server {
    listen 443 ssl;
    server_name monitor.yourdomain.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Caddy Example

```
monitor.yourdomain.com {
    reverse_proxy localhost:5000
}
```

## Troubleshooting

### Dashboard Won't Start

**Check Python version:**
```bash
python3 --version  # Should be 3.11 or higher
```

**Check dependencies:**
```bash
cd monitor
source venv/bin/activate
pip install -r requirements.txt
```

**Check port availability:**
```bash
lsof -i :5000  # See what's using port 5000
```

### "Invalid Password" Error

**Regenerate password hash:**
```bash
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('new-password'))"
```

Update `MONITOR_PASSWORD_HASH` in `.env`

### Backup Creation Fails

**Check Railway CLI:**
```bash
railway --version
railway whoami
railway status
```

**Check scripts:**
```bash
ls -la ../scripts/backup-vault.sh
chmod +x ../scripts/*.sh
```

### Restore Fails

**Check PostgreSQL client:**
```bash
psql --version
```

**Check database connection:**
```bash
railway run psql "$DATABASE_URL" -c "SELECT 1;"
```

**Check restore script:**
```bash
../scripts/restore-vault.sh --help
```

### "Script Not Found" Errors

**Verify directory structure:**
```bash
ls -la ../scripts/
ls -la ../backups/
```

**Check environment variables:**
```bash
echo $SCRIPTS_DIR
echo $BACKUP_DIR
```

### Logs Not Showing

**Check log directories:**
```bash
ls -la ../restore-logs/
ls -la ../verification-logs/
```

**Check permissions:**
```bash
chmod 755 ../restore-logs/ ../verification-logs/
```

## Development

### Running in Debug Mode

```bash
cd monitor
source venv/bin/activate
export MONITOR_DEBUG=true
python app.py
```

### Project Structure

```
monitor/
├── app.py                 # Flask application
├── templates/
│   └── index.html        # Dashboard UI
├── requirements.txt      # Python dependencies
├── Dockerfile           # Docker configuration
├── .env.example         # Example configuration
├── .env                 # Your configuration (gitignored)
├── setup.sh            # Setup script
└── venv/               # Virtual environment (gitignored)
```

### Adding Features

The dashboard is built with Flask and vanilla JavaScript. To add features:

1. Add API endpoint in `app.py`
2. Add frontend function in `templates/index.html`
3. Test locally
4. Update documentation

### Running Tests

```bash
cd monitor
source venv/bin/activate

# Test API endpoints
curl http://localhost:5000/api/status
curl http://localhost:5000/api/backups
curl http://localhost:5000/health
```

## Performance Considerations

### Resource Usage

- **Memory**: ~50-100 MB
- **CPU**: Minimal (spikes during backup/restore)
- **Disk**: Minimal (logs only)

### Scaling

- Dashboard is stateless (can run multiple instances)
- Operations are synchronous (one at a time)
- Long-running operations have timeouts

### Optimization Tips

1. **Reduce log verbosity** in production
2. **Limit log file size** with rotation
3. **Cache status** for frequently requested data
4. **Use CDN** for static assets in production

## Integration Examples

### Monitoring with Uptime Kuma

```yaml
monitors:
  - type: http
    url: https://monitor.yourdomain.com/health
    interval: 60
    name: Vaultwarden Monitor
```

### Slack Notifications

Use webhooks to send alerts:

```python
import requests

def send_slack_alert(message):
    webhook_url = "https://hooks.slack.com/services/YOUR/WEBHOOK/URL"
    requests.post(webhook_url, json={"text": message})

# Add to backup/restore functions
send_slack_alert("Backup created successfully!")
```

### Prometheus Metrics

Expose metrics endpoint:

```python
from prometheus_client import Counter, generate_latest

backup_counter = Counter('backups_created_total', 'Total backups created')

@app.route('/metrics')
def metrics():
    return generate_latest()
```

## Support

### Getting Help

1. Check this documentation
2. Review application logs
3. Check GitHub issues
4. Create new issue with logs

### Reporting Bugs

Include:
- Python version
- Flask version
- Environment (local, Docker, Railway)
- Error messages
- Steps to reproduce

## Roadmap

Future enhancements:
- [ ] Multi-user support with roles
- [ ] Scheduled backup creation
- [ ] Email notifications
- [ ] Backup encryption UI
- [ ] Download backups via UI
- [ ] Backup comparison tool
- [ ] API rate limiting
- [ ] Audit log viewer
- [ ] Dark/light theme toggle
- [ ] Mobile app

## License

This monitoring dashboard is part of the Vaultwarden Railway deployment project.

---

**Last Updated:** January 13, 2025
**Version:** 1.0.0
