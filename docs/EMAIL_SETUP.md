# Email Notifications Setup for Vaultwarden

This guide explains how to configure SMTP email notifications for your Vaultwarden instance.

## Overview

Email notifications enable:
- **Password hints** - Help users remember master passwords
- **2FA recovery** - Backup codes and recovery options
- **Emergency access** - Notifications for trusted contacts
- **Account verification** - Email confirmation for new accounts (if enabled)
- **Security alerts** - Login notifications and suspicious activity

## Supported Email Providers

### Recommended Providers

1. **Gmail** - Free, reliable, easy to set up
2. **Outlook/Hotmail** - Microsoft email service
3. **SendGrid** - Professional email service (100 emails/day free)
4. **Mailgun** - Transactional email service
5. **Amazon SES** - AWS email service
6. **Custom SMTP** - Any SMTP server

## Option 1: Gmail (Recommended for Personal Use)

### Prerequisites
- Gmail account
- App Password (required - regular password won't work)

### Step 1: Create Gmail App Password

1. Go to your Google Account: https://myaccount.google.com/
2. Click **Security** (left sidebar)
3. Under "How you sign in to Google", enable **2-Step Verification** (if not already enabled)
4. After 2FA is enabled, go back to Security
5. Click **2-Step Verification**
6. Scroll down to **App passwords**
7. Click **App passwords**
8. Select:
   - App: **Mail**
   - Device: **Other (Custom name)**
   - Enter name: **Vaultwarden**
9. Click **Generate**
10. **Copy the 16-character password** (shown once only)

### Step 2: Configure Railway Variables

Add these variables in Railway Dashboard:

```bash
SMTP_HOST=smtp.gmail.com
SMTP_FROM=your-email@gmail.com
SMTP_FROM_NAME=Vaultwarden
SMTP_SECURITY=starttls
SMTP_PORT=587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-16-char-app-password
```

**Important:**
- Use the **App Password** (16 characters, no spaces)
- NOT your regular Gmail password
- Format: `abcd efgh ijkl mnop` or `abcdefghijklmnop`

### Example Configuration

```
SMTP_HOST=smtp.gmail.com
SMTP_FROM=john.doe@gmail.com
SMTP_FROM_NAME=Vaultwarden Password Manager
SMTP_SECURITY=starttls
SMTP_PORT=587
SMTP_USERNAME=john.doe@gmail.com
SMTP_PASSWORD=abcdefghijklmnop
```

## Option 2: Outlook/Hotmail

### Configuration

```bash
SMTP_HOST=smtp-mail.outlook.com
SMTP_FROM=your-email@outlook.com
SMTP_FROM_NAME=Vaultwarden
SMTP_SECURITY=starttls
SMTP_PORT=587
SMTP_USERNAME=your-email@outlook.com
SMTP_PASSWORD=your-outlook-password
```

**Note:** Outlook may require an app password if you have 2FA enabled.

## Option 3: SendGrid (Professional/High Volume)

### Step 1: Create SendGrid Account

1. Sign up: https://sendgrid.com/
2. Free tier: 100 emails/day
3. Verify your sender email
4. Create an API key

### Step 2: Configure Railway Variables

```bash
SMTP_HOST=smtp.sendgrid.net
SMTP_FROM=your-verified-email@yourdomain.com
SMTP_FROM_NAME=Vaultwarden
SMTP_SECURITY=starttls
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your-sendgrid-api-key
```

**Important:**
- Username is literally `apikey`
- Password is your SendGrid API key
- Sender email must be verified in SendGrid

## Option 4: Custom SMTP Server

### Generic Configuration

```bash
SMTP_HOST=mail.yourserver.com
SMTP_FROM=vaultwarden@yourdomain.com
SMTP_FROM_NAME=Vaultwarden
SMTP_SECURITY=starttls  # or 'force_tls' or 'off'
SMTP_PORT=587           # or 465 for SSL, 25 for unencrypted
SMTP_USERNAME=your-smtp-username
SMTP_PASSWORD=your-smtp-password
```

### Common SMTP Ports

- **Port 587** - STARTTLS (recommended)
- **Port 465** - SSL/TLS
- **Port 25** - Unencrypted (not recommended)

### Security Options

- `starttls` - Upgrade to TLS (recommended, port 587)
- `force_tls` - Require TLS (port 465)
- `off` - No encryption (not recommended)

## Environment Variables Reference

### Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SMTP_HOST` | SMTP server hostname | `smtp.gmail.com` |
| `SMTP_FROM` | Sender email address | `vaultwarden@example.com` |
| `SMTP_PORT` | SMTP server port | `587` |
| `SMTP_SECURITY` | Encryption method | `starttls` |
| `SMTP_USERNAME` | SMTP login username | `your-email@gmail.com` |
| `SMTP_PASSWORD` | SMTP login password | `your-app-password` |

### Optional Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SMTP_FROM_NAME` | Display name for emails | `Vaultwarden` |
| `SMTP_TIMEOUT` | Connection timeout (seconds) | `15` |
| `SMTP_AUTH_MECHANISM` | Auth method | `Plain` (auto-detect) |
| `SMTP_ACCEPT_INVALID_CERTS` | Allow invalid SSL certs | `false` |
| `SMTP_ACCEPT_INVALID_HOSTNAMES` | Allow hostname mismatch | `false` |

### Email Feature Controls

| Variable | Description | Default |
|----------|-------------|---------|
| `SHOW_PASSWORD_HINT` | Allow password hints via email | `false` |
| `SIGNUPS_VERIFY` | Require email verification for signups | `false` |

## Setup via Railway Dashboard

### Method 1: Railway Dashboard (Recommended)

1. Go to: https://railway.app/dashboard
2. Click **"vaultwarden-railway"** project
3. Click your **main Vaultwarden service**
4. Click **"Variables"** tab
5. Click **"New Variable"** for each SMTP setting
6. Service auto-deploys with new settings

### Method 2: Railway CLI

```bash
railway variables --set "SMTP_HOST=smtp.gmail.com" \
                  --set "SMTP_FROM=your-email@gmail.com" \
                  --set "SMTP_FROM_NAME=Vaultwarden" \
                  --set "SMTP_SECURITY=starttls" \
                  --set "SMTP_PORT=587" \
                  --set "SMTP_USERNAME=your-email@gmail.com" \
                  --set "SMTP_PASSWORD=your-app-password"
```

## Testing Email Configuration

### Test 1: Vaultwarden Admin Panel

1. Go to: https://your-app.up.railway.app/admin
2. Login with admin token
3. Click **"Diagnostics"**
4. Look for SMTP configuration status
5. Check for any SMTP errors in the diagnostics

### Test 2: Send Test Email (Admin Panel)

Some Vaultwarden versions have a built-in test email feature:

1. Admin panel → Settings
2. Look for "Send test email" option
3. Enter a test email address
4. Click send
5. Check inbox (and spam folder)

### Test 3: Request Password Hint

**Prerequisites:**
- Set `SHOW_PASSWORD_HINT=true` in Railway variables
- Add a password hint to your account

**Steps:**
1. Logout of Vaultwarden
2. Go to login page
3. Click "Get password hint"
4. Enter your email
5. Check your inbox for the hint email

### Test 4: Check Railway Logs

```bash
railway logs
```

Look for:
- `SMTP configured successfully`
- `Email sent to ...`
- SMTP connection errors (if any)

## Troubleshooting

### Common Issues

#### 1. "Authentication failed" or "Invalid credentials"

**Cause:** Wrong username/password

**Solutions:**
- Gmail: Use **App Password**, not regular password
- Outlook: May need app password if 2FA enabled
- Verify username is correct (often the full email)
- Check for typos in password
- Ensure no extra spaces in credentials

#### 2. "Connection timeout" or "Could not connect to SMTP server"

**Cause:** Wrong host or port

**Solutions:**
- Verify `SMTP_HOST` is correct
- Check `SMTP_PORT` matches security setting:
  - Port 587 for `starttls`
  - Port 465 for `force_tls`
- Test connectivity: `telnet smtp.gmail.com 587`
- Check Railway allows outbound SMTP connections

#### 3. "Certificate verification failed"

**Cause:** SSL/TLS certificate issues

**Solutions:**
- Verify `SMTP_SECURITY` setting is correct
- For self-signed certs, set:
  - `SMTP_ACCEPT_INVALID_CERTS=true`
  - `SMTP_ACCEPT_INVALID_HOSTNAMES=true`
- Use `starttls` instead of `force_tls`

#### 4. Emails go to spam

**Cause:** Email provider spam filters

**Solutions:**
- Use a verified domain
- Configure SPF, DKIM, DMARC records (advanced)
- Use professional email service (SendGrid, Mailgun)
- Ask users to whitelist the sender address
- Check sender reputation

#### 5. Gmail: "Less secure app access"

**Cause:** Trying to use regular password

**Solution:**
- Gmail deprecated "less secure apps"
- **Must use App Password** (see Gmail setup above)
- Enable 2FA first, then create App Password

### Debugging Steps

1. **Check Railway logs:**
   ```bash
   railway logs | grep -i smtp
   railway logs | grep -i email
   ```

2. **Verify variables are set:**
   ```bash
   railway variables | grep SMTP
   ```

3. **Test SMTP connection manually:**
   ```bash
   telnet smtp.gmail.com 587
   # or
   openssl s_client -starttls smtp -connect smtp.gmail.com:587
   ```

4. **Check admin diagnostics:**
   - Go to `/admin` panel
   - Review diagnostics section
   - Look for SMTP status

## Security Best Practices

1. **Use App Passwords**
   - Never use main account passwords
   - Create dedicated app passwords
   - Rotate passwords periodically

2. **Enable 2FA on Email Account**
   - Protect the email account itself
   - Use 2FA on Gmail/Outlook
   - Store backup codes securely

3. **Limit Password Hints**
   - Keep `SHOW_PASSWORD_HINT=false` if possible
   - Password hints can be security risks
   - Encourage strong, memorable passwords

4. **Monitor Email Activity**
   - Check Railway logs for email sending
   - Review sent emails in SMTP account
   - Watch for unusual activity

5. **Use Dedicated Email**
   - Consider separate email for Vaultwarden
   - Not your personal daily email
   - Easier to track and monitor

## Advanced Configuration

### Custom Email Templates

Vaultwarden uses default templates, but you can customize:

1. Mount custom templates (advanced)
2. Edit Handlebars templates
3. See: https://github.com/dani-garcia/vaultwarden/tree/main/src/static/templates

### SPF/DKIM/DMARC Setup

For custom domains to avoid spam:

**SPF Record (DNS TXT):**
```
v=spf1 include:_spf.google.com ~all
```

**DKIM:** Configure in Gmail/SendGrid settings

**DMARC Record (DNS TXT):**
```
_dmarc.yourdomain.com
v=DMARC1; p=quarantine; rua=mailto:admin@yourdomain.com
```

### Rate Limiting Emails

Vaultwarden has built-in rate limiting for emails to prevent abuse.

## Complete Gmail Example

```bash
# Railway Variables
SMTP_HOST=smtp.gmail.com
SMTP_FROM=myname@gmail.com
SMTP_FROM_NAME=My Vaultwarden
SMTP_SECURITY=starttls
SMTP_PORT=587
SMTP_USERNAME=myname@gmail.com
SMTP_PASSWORD=abcd efgh ijkl mnop  # App Password from Google

# Optional
SMTP_TIMEOUT=15
SHOW_PASSWORD_HINT=false
```

## Resources

- [Vaultwarden SMTP Config](https://github.com/dani-garcia/vaultwarden/wiki/SMTP-Configuration)
- [Gmail App Passwords](https://support.google.com/accounts/answer/185833)
- [SendGrid Setup](https://sendgrid.com/docs/)
- [SMTP Test Tool](https://www.smtper.net/)

## Support

Having issues with email configuration?

1. Check Railway logs: `railway logs | grep -i smtp`
2. Verify all SMTP variables are set correctly
3. Test with Gmail first (easiest to configure)
4. Review troubleshooting section above
5. Check Vaultwarden admin diagnostics

---

**Once configured, your Vaultwarden instance can send email notifications for password hints, 2FA recovery, and security alerts!**
