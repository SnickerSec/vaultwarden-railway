FROM python:3.12-alpine

# Upgrade base packages to pick up security fixes, then install dependencies
RUN apk upgrade --no-cache && apk add --no-cache \
    curl \
    ca-certificates \
    gzip \
    bash \
    postgresql17-client

# Install Railway CLI from pinned release
ARG RAILWAY_CLI_VERSION=3.14.0
RUN curl -fsSL -o /tmp/railway.tar.gz \
        "https://github.com/railwayapp/cli/releases/download/v${RAILWAY_CLI_VERSION}/railway-v${RAILWAY_CLI_VERSION}-x86_64-unknown-linux-musl.tar.gz" \
    && tar -xzf /tmp/railway.tar.gz -C /usr/local/bin \
    && rm /tmp/railway.tar.gz \
    && railway --version

# Set working directory
WORKDIR /app

# Upgrade pip, setuptools, and wheel to fix known CVEs
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY *.py .
COPY templates/ templates/

# Copy backup scripts
COPY scripts/backup-vault.sh /scripts/
COPY scripts/restore-vault.sh /scripts/
COPY scripts/verify-backup.sh /scripts/

# Copy lib directory files
RUN mkdir -p /scripts/lib
COPY scripts/lib/*.sh /scripts/lib/

# Make scripts executable
RUN chmod +x /scripts/*.sh /scripts/lib/*.sh

# Create necessary directories
RUN mkdir -p /backups /restore-logs /verification-logs

# Create non-root user and set ownership
RUN addgroup -S monitor && adduser -S -G monitor -h /app -s /sbin/nologin monitor \
    && chown -R monitor:monitor /app /backups /restore-logs /verification-logs /scripts

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV BACKUP_DIR=/backups
ENV RESTORE_LOG_DIR=/restore-logs
ENV VERIFICATION_LOG_DIR=/verification-logs
ENV SCRIPTS_DIR=/scripts
ENV MONITOR_PORT=5000

# Switch to non-root user
USER monitor

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run the application
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "2", "--timeout", "120", "app:app"]
