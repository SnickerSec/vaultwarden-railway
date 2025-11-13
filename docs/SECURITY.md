# Security Guide

This guide covers security best practices and how to secure your Vaultwarden instance.

## Admin Token Security

### The Warning

If you see this in your logs:
```
[NOTICE] You are using a plain text `ADMIN_TOKEN` which is insecure.
Please generate a secure Argon2 PHC string by using `vaultwarden hash` or `argon2`.
```

**This is a warning, not an error.** Your deployment works fine, but using a plain text token is less secure.

### Why Use Argon2 Hashing?

- **Plain text tokens** are vulnerable if your environment variables are exposed
- **Argon2 hashed tokens** add an extra layer of security - even if someone sees the hash, they can't easily reverse it to get your password
- The hash is stored in Railway, but you use a simple password to access the admin panel

### How to Generate a Secure Admin Token

#### Method 1: Use the Helper Script (Recommended)

```bash
./scripts/generate-admin-token.sh
```

This will:
1. Generate a secure Argon2 hash
2. Provide you with a simple password to remember
3. Give you the hash to add to Railway

#### Method 2: Use Docker Manually

```bash
# Generate with a password you choose
docker run --rm -it vaultwarden/server:latest \
  /vaultwarden hash --preset owasp

# Or generate with random password
docker run --rm -it vaultwarden/server:latest \
  /vaultwarden hash --preset owasp "$(openssl rand -base64 32)"
```

#### Method 3: Keep Plain Text (Less Secure)

If you prefer simplicity over maximum security, you can keep using a plain text token:

```bash
# Generate a strong random token
openssl rand -base64 48
```

The warning will continue to appear, but functionality is not affected.

### Update Railway Configuration

Once you have your Argon2 hash:

1. Go to Railway dashboard
2. Click your Vaultwarden service
3. Go to "Variables" tab
4. Find `ADMIN_TOKEN`
5. Replace the plain text value with the Argon2 hash
6. Save (Railway will auto-redeploy)

### Accessing Admin Panel

After updating to Argon2:

1. Visit: `https://your-domain.railway.app/admin`
2. Enter the **password you used** (not the hash!)
3. The password is what you entered when generating the hash

## Other Security Best Practices

### 1. Disable Signups After Account Creation

```bash
# In Railway environment variables
SIGNUPS_ALLOWED=false
```

### 2. Enable 2FA on Your Account

1. Log into your Vaultwarden web vault
2. Go to Settings → Security → Two-step Login
3. Enable "Authenticator App"
4. Scan the QR code with an authenticator app

### 3. Use Strong Master Password

- **Minimum 14+ characters**
- Mix of uppercase, lowercase, numbers, symbols
- Use a passphrase (e.g., "correct-horse-battery-staple-purple-monkey")
- **Never reuse** this password elsewhere

### 4. Regular Backups

```bash
# Export vault regularly
# From web vault: Tools → Export Vault → Encrypted JSON
```

Set up automated backups:
```bash
./scripts/backup-vault.sh
```

### 5. Use PostgreSQL for Production

SQLite works, but PostgreSQL is more reliable:

1. In Railway: Click "New" → "Database" → "PostgreSQL"
2. Railway auto-injects `DATABASE_URL`
3. Redeploy your service

### 6. Configure Email for Recovery

Add SMTP settings to enable password hints and 2FA recovery:

```bash
SMTP_HOST=smtp.gmail.com
SMTP_FROM=your-email@gmail.com
SMTP_PORT=587
SMTP_SECURITY=starttls
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
```

### 7. Monitor Access Logs

Check Railway logs regularly:
```bash
railway logs
```

Look for:
- Failed login attempts
- Unusual access patterns
- Error messages

### 8. Keep Vaultwarden Updated

This deployment automatically updates to the latest version on every rebuild. To manually trigger:

```bash
git commit --allow-empty -m "chore: trigger update"
git push
```

### 9. Secure Your Railway Account

- Enable 2FA on your Railway account
- Use a strong password
- Review access tokens regularly
- Don't share deployment URLs publicly

### 10. Optional: Add OAuth2 Layer

For extra security, add Google OAuth2:
- See [GOOGLE_AUTH_SETUP.md](GOOGLE_AUTH_SETUP.md)
- Requires Google login before accessing Vaultwarden
- Two layers: OAuth + Master Password

## Security Checklist

After deployment, verify:

- [ ] Argon2 hashed admin token configured
- [ ] Signups disabled after account creation
- [ ] 2FA enabled on your account
- [ ] Strong master password set
- [ ] Regular vault exports scheduled
- [ ] PostgreSQL database added
- [ ] HTTPS enabled (automatic on Railway)
- [ ] Email configured for recovery
- [ ] Railway account has 2FA enabled
- [ ] Latest Vaultwarden version running

## Reporting Security Issues

- **Vaultwarden issues**: https://github.com/dani-garcia/vaultwarden/security
- **Railway issues**: https://railway.app/legal/security
- **This deployment**: Create a private security advisory on GitHub

## Additional Resources

- [Vaultwarden Security Wiki](https://github.com/dani-garcia/vaultwarden/wiki/Security)
- [Bitwarden Security Whitepaper](https://bitwarden.com/help/bitwarden-security-white-paper/)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html)
