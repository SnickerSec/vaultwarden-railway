#!/usr/bin/env python3
"""
Vaultwarden Backup & Restore Monitoring Dashboard

A web-based dashboard for monitoring, creating, and restoring Vaultwarden backups.
Integrates with existing backup and restore scripts.
"""

import logging
import secrets

from flask import Flask, g

from config import Config, ensure_directories
from extensions import csrf, limiter
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

    # Validate required config
    if not Config.ADMIN_PASSWORD_HASH:
        raise RuntimeError(
            "MONITOR_PASSWORD_HASH environment variable is required. "
            "Generate one with: python -c \"from werkzeug.security import generate_password_hash; print(generate_password_hash('yourpassword'))\""
        )

    # Load configuration
    app.config['SECRET_KEY'] = Config.SECRET_KEY
    app.config['JSON_SORT_KEYS'] = Config.JSON_SORT_KEYS
    app.config['SESSION_COOKIE_HTTPONLY'] = True
    app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
    app.config['SESSION_COOKIE_SECURE'] = True
    app.config['PERMANENT_SESSION_LIFETIME'] = 1800  # 30 minutes

    # Initialize CSRF protection
    csrf.init_app(app)

    # Initialize rate limiter
    limiter.init_app(app)

    # Ensure directories exist
    ensure_directories()

    # Register blueprints
    app.register_blueprint(main)
    app.register_blueprint(api, url_prefix='/api')

    # Generate a CSP nonce per request
    @app.before_request
    def generate_csp_nonce():
        g.csp_nonce = secrets.token_urlsafe(32)

    # Security headers
    @app.after_request
    def set_security_headers(response):
        nonce = getattr(g, 'csp_nonce', '')
        response.headers['X-Frame-Options'] = 'DENY'
        response.headers['X-Content-Type-Options'] = 'nosniff'
        response.headers['Strict-Transport-Security'] = 'max-age=31536000; includeSubDomains'
        response.headers['Referrer-Policy'] = 'strict-origin-when-cross-origin'
        response.headers['Content-Security-Policy'] = (
            "default-src 'self'; "
            f"script-src 'self' 'nonce-{nonce}'; "
            f"style-src 'self' 'nonce-{nonce}'; "
            "img-src 'self'; "
            "frame-ancestors 'none'"
        )
        return response

    return app


# Create application instance
app = create_app()


if __name__ == '__main__':
    logger.info(f"Starting Vaultwarden Monitor on port {Config.PORT}")
    logger.info(f"Backup directory: {Config.BACKUP_DIR.resolve()}")
    logger.info(f"Scripts directory: {Config.SCRIPTS_DIR.resolve()}")

    app.run(host=Config.HOST, port=Config.PORT, debug=Config.DEBUG)
