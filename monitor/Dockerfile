FROM python:3.11.12-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    gnupg \
    lsb-release \
    ca-certificates \
    gzip \
    && rm -rf /var/lib/apt/lists/*

# Install PostgreSQL client tools
RUN echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg && \
    apt-get update && \
    apt-get install -y postgresql-client-17 && \
    rm -rf /var/lib/apt/lists/*

# Install Railway CLI from pinned release
ARG RAILWAY_CLI_VERSION=3.14.0
RUN curl -fsSL -o /tmp/railway.tar.gz \
        "https://github.com/railwayapp/cli/releases/download/v${RAILWAY_CLI_VERSION}/railway-v${RAILWAY_CLI_VERSION}-linux-amd64.tar.gz" \
    && tar -xzf /tmp/railway.tar.gz -C /usr/local/bin \
    && rm /tmp/railway.tar.gz \
    && railway --version \
    || echo "Railway CLI installation failed, continuing anyway..."

# Set working directory
WORKDIR /app

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
RUN groupadd -r monitor && useradd -r -g monitor -d /app -s /sbin/nologin monitor \
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
