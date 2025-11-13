# Rate Limiting Configuration for Vaultwarden

This guide explains how to configure rate limiting to protect your Vaultwarden instance from abuse and brute-force attacks.

## Overview

Vaultwarden includes built-in rate limiting for login attempts and admin endpoints. Rate limiting helps protect against:
- Brute-force password attacks
- Denial of service (DoS) attempts
- API abuse
- Credential stuffing attacks

## Rate Limiting Environment Variables

### Login Rate Limiting

**`LOGIN_RATELIMIT_MAX_BURST`**
- Maximum number of login requests allowed in a burst
- Default: `10`
- Recommended: `5-10`
- Example: `LOGIN_RATELIMIT_MAX_BURST=10`

**`LOGIN_RATELIMIT_SECONDS`**
- Time window (in seconds) for rate limiting login attempts
- Default: `60`
- Recommended: `60` (1 minute)
- Example: `LOGIN_RATELIMIT_SECONDS=60`

This means: Allow `LOGIN_RATELIMIT_MAX_BURST` login attempts per `LOGIN_RATELIMIT_SECONDS` seconds per IP address.

**Example:** With defaults (10 burst, 60 seconds), a user can attempt 10 logins per minute per IP.

### Admin Panel Rate Limiting

**`ADMIN_RATELIMIT_MAX_BURST`**
- Maximum admin requests in a burst
- Default: `3`
- Recommended: `3-5`
- Example: `ADMIN_RATELIMIT_MAX_BURST=3`

**`ADMIN_RATELIMIT_SECONDS`**
- Time window for admin rate limiting
- Default: `300` (5 minutes)
- Recommended: `300-600`
- Example: `ADMIN_RATELIMIT_SECONDS=300`

### Additional Security Settings

**`IP_HEADER`**
- Header to use for client IP detection (important for Railway/proxy setups)
- Default: `X-Real-IP`
- For Railway: Use `X-Forwarded-For`
- Example: `IP_HEADER=X-Forwarded-For`

**`ICON_DOWNLOAD_TIMEOUT`**
- Timeout for downloading website icons (prevents DoS via icon requests)
- Default: `10` seconds
- Recommended: `10`
- Example: `ICON_DOWNLOAD_TIMEOUT=10`

**`ICON_BLACKLIST_REGEX`**
- Regex to blacklist icon download domains
- Prevents downloading icons from private IP ranges
- Default: `^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)`
- Example: `ICON_BLACKLIST_REGEX=^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)`

## Recommended Configuration

### For Personal Use (Low Traffic)
```bash
LOGIN_RATELIMIT_MAX_BURST=10
LOGIN_RATELIMIT_SECONDS=60
ADMIN_RATELIMIT_MAX_BURST=3
ADMIN_RATELIMIT_SECONDS=300
IP_HEADER=X-Forwarded-For
```

### For Shared/Family Use (Medium Traffic)
```bash
LOGIN_RATELIMIT_MAX_BURST=15
LOGIN_RATELIMIT_SECONDS=60
ADMIN_RATELIMIT_MAX_BURST=5
ADMIN_RATELIMIT_SECONDS=300
IP_HEADER=X-Forwarded-For
```

### For Strict Security (High Security)
```bash
LOGIN_RATELIMIT_MAX_BURST=5
LOGIN_RATELIMIT_SECONDS=60
ADMIN_RATELIMIT_MAX_BURST=3
ADMIN_RATELIMIT_SECONDS=600
IP_HEADER=X-Forwarded-For
ICON_DOWNLOAD_TIMEOUT=5
```

## How to Configure on Railway

### Method 1: Railway Dashboard

1. Go to: https://railway.app/project/your-project/production
2. Click on your Vaultwarden service
3. Go to "Variables" tab
4. Click "New Variable" for each setting:
   - Variable: `LOGIN_RATELIMIT_MAX_BURST` → Value: `10`
   - Variable: `LOGIN_RATELIMIT_SECONDS` → Value: `60`
   - Variable: `ADMIN_RATELIMIT_MAX_BURST` → Value: `3`
   - Variable: `ADMIN_RATELIMIT_SECONDS` → Value: `300`
   - Variable: `IP_HEADER` → Value: `X-Forwarded-For`
5. Click "Deploy" to restart with new settings

### Method 2: Railway CLI

```bash
railway variables set LOGIN_RATELIMIT_MAX_BURST=10
railway variables set LOGIN_RATELIMIT_SECONDS=60
railway variables set ADMIN_RATELIMIT_MAX_BURST=3
railway variables set ADMIN_RATELIMIT_SECONDS=300
railway variables set IP_HEADER=X-Forwarded-For
```

Then redeploy:
```bash
railway up --detach
```

## Testing Rate Limiting

### Test Login Rate Limiting

Try logging in with incorrect credentials multiple times:

```bash
# Attempt 11 failed logins in quick succession
for i in {1..11}; do
  curl -X POST https://your-app.up.railway.app/identity/connect/token \
    -d "grant_type=password&username=test@example.com&password=wrong" \
    -H "Content-Type: application/x-www-form-urlencoded"
  echo "Attempt $i"
done
```

Expected behavior:
- First 10 attempts: Return error response (wrong password)
- 11th attempt: Get rate limited (HTTP 429 or similar)

### Test Admin Rate Limiting

Try accessing admin panel multiple times:

```bash
for i in {1..4}; do
  curl https://your-app.up.railway.app/admin
  echo "Attempt $i"
done
```

Expected behavior:
- First 3 attempts: Normal response
- 4th attempt: Rate limited

## Monitoring Rate Limiting

### Check Logs

View Railway logs to see rate limiting in action:

```bash
railway logs
```

Look for messages like:
- `Rate limit exceeded for IP ...`
- `Too many requests`
- `429 Too Many Requests`

### Admin Panel Diagnostics

1. Go to: https://your-app.up.railway.app/admin
2. Login with admin token
3. Click "Diagnostics"
4. Review connection and security information

## What Happens When Rate Limited?

When a client exceeds rate limits:

1. **HTTP 429 Response** - "Too Many Requests" status code
2. **Temporary Block** - IP is blocked for the configured time window
3. **Automatic Unblock** - Block lifts after the time window expires
4. **No Permanent Ban** - Rate limiting is temporary, not a permanent block

## Best Practices

1. **Start Conservative**
   - Begin with default or stricter settings
   - Relax limits only if legitimate users are affected

2. **Monitor Logs**
   - Regularly check logs for rate limit events
   - Identify patterns of abuse

3. **Combine with Other Security**
   - Use rate limiting WITH 2FA (not instead of)
   - Keep signups disabled
   - Use strong admin token
   - Consider Cloudflare or fail2ban for additional protection

4. **Adjust for Your Use Case**
   - Personal use: Stricter limits OK
   - Family/shared: May need higher burst limits
   - Multiple users: Balance security vs usability

5. **Behind Proxy/CDN**
   - Always set `IP_HEADER=X-Forwarded-For` on Railway
   - Verify correct IP detection in admin diagnostics

## Troubleshooting

### Legitimate Users Getting Rate Limited

**Problem:** Real users can't login due to rate limiting

**Solution:**
```bash
# Increase burst limit
railway variables set LOGIN_RATELIMIT_MAX_BURST=15

# Or increase time window
railway variables set LOGIN_RATELIMIT_SECONDS=120
```

### Rate Limiting Not Working

**Problem:** No rate limiting seems to be applied

**Check:**
1. Variables are set correctly in Railway
2. `IP_HEADER` is set to `X-Forwarded-For`
3. Service was redeployed after adding variables
4. Test from external IP (not localhost)

**Debug:**
```bash
# Check current variables
railway variables

# Verify IP_HEADER setting
railway variables | grep IP_HEADER
```

### All Requests Blocked

**Problem:** Every request is rate limited

**Cause:** Incorrect `IP_HEADER` setting - all requests appear from same IP

**Fix:**
```bash
railway variables set IP_HEADER=X-Forwarded-For
railway up --detach
```

## Advanced: Additional Protection Layers

### 1. Cloudflare Rate Limiting

If using Cloudflare:
- Dashboard → Security → WAF
- Create rate limiting rule
- Set rules for `/identity/connect/token`

### 2. Railway Network Policies

Railway Enterprise offers:
- IP whitelisting
- Geographic restrictions
- Advanced DDoS protection

### 3. fail2ban (Self-Hosted Alternative)

For self-hosted deployments:
```bash
# /etc/fail2ban/filter.d/vaultwarden.conf
[Definition]
failregex = ^.*Username or password is incorrect\. Try again\. IP: <HOST>\..*$
ignoreregex =
```

## Security Considerations

1. **Rate Limiting ≠ Complete Security**
   - It slows down attacks but doesn't prevent them
   - Always use strong passwords and 2FA

2. **Distributed Attacks**
   - IP-based rate limiting can be bypassed with botnets
   - Consider additional layers (Cloudflare, etc.)

3. **Legitimate Traffic**
   - Too strict = poor user experience
   - Too loose = less protection
   - Find balance for your use case

4. **Shared IPs**
   - Multiple users behind same NAT/VPN may share IP
   - May need higher limits in some scenarios

## Resources

- [Vaultwarden Configuration Guide](https://github.com/dani-garcia/vaultwarden/wiki/Configuration-overview)
- [Vaultwarden Security](https://github.com/dani-garcia/vaultwarden/wiki/Hardening-Guide)
- [Railway Environment Variables](https://docs.railway.app/develop/variables)

## Support

Having issues with rate limiting?

1. Check Railway logs: `railway logs`
2. Verify variables: `railway variables`
3. Test from external IP
4. Check admin diagnostics panel
5. Review this guide's troubleshooting section

---

**Remember:** Rate limiting is one layer of defense. Always use it in combination with strong passwords, 2FA, disabled signups, and a secure admin token.
