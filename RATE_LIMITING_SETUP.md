# Rate Limiting Setup - Quick Guide

## Recommended Settings Applied

Configure these variables in Railway Dashboard to enable rate limiting:

### Go to Railway Dashboard

1. Visit: https://railway.app/dashboard
2. Click on **"vaultwarden-railway"** project
3. Click on your **main Vaultwarden service** (not PostgreSQL)
4. Click **"Variables"** tab

### Add These 5 Variables

Click "New Variable" for each:

| Variable Name | Value | What It Does |
|---------------|-------|--------------|
| `LOGIN_RATELIMIT_MAX_BURST` | `10` | Max login attempts in burst |
| `LOGIN_RATELIMIT_SECONDS` | `60` | Time window for login limits (1 minute) |
| `ADMIN_RATELIMIT_MAX_BURST` | `3` | Max admin panel attempts |
| `ADMIN_RATELIMIT_SECONDS` | `300` | Time window for admin limits (5 minutes) |
| `IP_HEADER` | `X-Forwarded-For` | Correct IP detection for Railway |

### What This Means

**Login Protection:**
- Users can attempt **10 logins per minute** per IP address
- After 10 failed attempts, they're blocked for 1 minute
- Protects against brute-force password attacks

**Admin Panel Protection:**
- **3 admin access attempts per 5 minutes** per IP
- After 3 attempts, blocked for 5 minutes
- Protects admin panel from unauthorized access

**IP Detection:**
- `X-Forwarded-For` header ensures Railway correctly identifies user IPs
- Without this, all users might appear as the same IP

### After Adding Variables

The service will automatically redeploy with the new settings (takes ~1-2 minutes).

### Verify It's Working

1. Wait for deployment to complete
2. Go to: https://vaultwarden-railway-production.up.railway.app
3. Try logging in with wrong password 11 times quickly
4. The 11th attempt should be rate limited

### Check Logs

```bash
railway logs
```

Look for rate limiting messages after it's active.

## Alternative: Manual Quick Setup

If you prefer, paste these commands directly in Railway's Variables tab using the "Raw Editor":

```
LOGIN_RATELIMIT_MAX_BURST=10
LOGIN_RATELIMIT_SECONDS=60
ADMIN_RATELIMIT_MAX_BURST=3
ADMIN_RATELIMIT_SECONDS=300
IP_HEADER=X-Forwarded-For
```

## Email Configuration

Want to enable email notifications for password hints, 2FA recovery, and security alerts?

See: [docs/EMAIL_SETUP.md](docs/EMAIL_SETUP.md)

## More Information

- Full documentation: [docs/RATE_LIMITING.md](docs/RATE_LIMITING.md)
- Different security levels available (Strict, Relaxed, Custom)
- Testing procedures
- Troubleshooting guide

---

**Once configured, your Vaultwarden instance will be protected against brute-force attacks!** 🛡️
