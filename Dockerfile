FROM vaultwarden/server:latest

# Expose the default Vaultwarden port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:80/alive || exit 1
