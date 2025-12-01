#!/usr/bin/env python3
"""
Vaultwarden Backup & Restore Monitoring Dashboard

A web-based dashboard for monitoring, creating, and restoring Vaultwarden backups.
Integrates with existing backup and restore scripts.
"""

import logging
from flask import Flask

from config import Config, ensure_directories
from routes import api, main

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def create_app():
    """Application factory."""
    app = Flask(__name__)

    # Load configuration
    app.config['SECRET_KEY'] = Config.SECRET_KEY
    app.config['JSON_SORT_KEYS'] = Config.JSON_SORT_KEYS

    # Ensure directories exist
    ensure_directories()

    # Register blueprints
    app.register_blueprint(main)
    app.register_blueprint(api, url_prefix='/api')

    return app


# Create application instance
app = create_app()


if __name__ == '__main__':
    logger.info(f"Starting Vaultwarden Monitor on port {Config.PORT}")
    logger.info(f"Backup directory: {Config.BACKUP_DIR.resolve()}")
    logger.info(f"Scripts directory: {Config.SCRIPTS_DIR.resolve()}")

    app.run(host=Config.HOST, port=Config.PORT, debug=Config.DEBUG)
