# Google OAuth Authentication Setup

This guide shows you how to add Google authentication in front of your Vaultwarden instance for an extra layer of security.

## What This Does

When enabled, users must:
1. **First authenticate with Google** (your Google account)
2. **Then log into Vaultwarden** (your master password)

This provides **two layers of protection**:
- Layer 1: Google OAuth (who can access the login page)
- Layer 2: Vaultwarden master password (access to your vault)

## Architecture

```
User → Google Auth (OAuth2 Proxy) → Vaultwarden
       ↑                              ↑
       Layer 1 Protection             Layer 2 Protection
```

## Prerequisites

- Google account
- Access to Google Cloud Console
- Railway deployment already set up

## Step 1: Create Google OAuth Credentials

### 1.1 Go to Google Cloud Console

Visit: https://console.cloud.google.com/

### 1.2 Create a New Project (or select existing)

1. Click the project dropdown at the top
2. Click "New Project"
3. Name it: `Vaultwarden OAuth`
4. Click "Create"

### 1.3 Enable Google+ API

1. Go to "APIs & Services" → "Library"
2. Search for "Google+ API"
3. Click "Enable"

### 1.4 Configure OAuth Consent Screen

1. Go to "APIs & Services" → "OAuth consent screen"
2. Choose "External" (unless you have Google Workspace)
3. Fill in required fields:
   - **App name**: `Vaultwarden`
   - **User support email**: Your email
   - **Developer contact**: Your email
4. Click "Save and Continue"
5. Skip "Scopes" (click "Save and Continue")
6. Add test users (your email addresses that should have access)
7. Click "Save and Continue"

### 1.5 Create OAuth 2.0 Client ID

1. Go to "APIs & Services" → "Credentials"
2. Click "Create Credentials" → "OAuth client ID"
3. Application type: **Web application**
4. Name: `Vaultwarden Railway`
5. Add Authorized redirect URIs:
   ```
   https://your-app.up.railway.app/oauth2/callback
   ```
   (Replace with your actual Railway URL)
6. Click "Create"
7. **Save the Client ID and Client Secret** - you'll need these!

## Step 2: Generate Cookie Secret

On your local machine:

```bash
openssl rand -base64 32
```

Save this output - this is your `OAUTH2_COOKIE_SECRET`

## Step 3: Choose Deployment Method

You have two options:

### Option A: Docker Compose (Simpler - for local or single Railway service)
Best for: Testing locally or if Railway supports multi-container deployments

### Option B: Separate Railway Services (Recommended for Railway)
Best for: Production Railway deployment

---

## Option A: Docker Compose Setup

### Update Environment Variables

Edit your `.env` file:

```bash
# Your existing variables
DOMAIN=https://your-app.up.railway.app
ADMIN_TOKEN=your-admin-token

# Add these new variables
GOOGLE_CLIENT_ID=your-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-client-secret
OAUTH2_COOKIE_SECRET=your-cookie-secret-from-step-2

# Restrict to specific email domain (optional)
OAUTH2_EMAIL_DOMAINS=*  # Use * for all Google accounts
# OAUTH2_EMAIL_DOMAINS=yourdomain.com  # Or restrict to your domain
```

### Deploy

```bash
docker-compose up -d
```

The `docker-compose.yml` is already configured with OAuth2 Proxy!

---

## Option B: Separate Railway Services (Recommended)

Railway doesn't natively support multi-container deployments, so we'll deploy two separate services that communicate.

### Step 3.1: Update Your Current Vaultwarden Service

1. In Railway, go to your Vaultwarden service variables
2. Change/add:
   ```
   ROCKET_ADDRESS=0.0.0.0
   ROCKET_PORT=80
   ```

3. Note your service's internal URL (in Railway):
   - Format: `vaultwarden.railway.internal` or similar
   - Find in: Service → Settings → Networking

### Step 3.2: Deploy OAuth2 Proxy Service

1. Create a new file `Dockerfile.oauth2` in your repo:

```dockerfile
FROM quay.io/oauth2-proxy/oauth2-proxy:latest

EXPOSE 80

CMD ["oauth2-proxy", \
  "--http-address=0.0.0.0:80", \
  "--upstream=${VAULTWARDEN_URL}", \
  "--provider=google", \
  "--client-id=${GOOGLE_CLIENT_ID}", \
  "--client-secret=${GOOGLE_CLIENT_SECRET}", \
  "--cookie-secret=${OAUTH2_COOKIE_SECRET}", \
  "--email-domain=${OAUTH2_EMAIL_DOMAINS:-*}", \
  "--redirect-url=${DOMAIN}/oauth2/callback", \
  "--cookie-secure=true", \
  "--cookie-httponly=true", \
  "--cookie-samesite=lax", \
  "--pass-access-token=true", \
  "--pass-user-headers=true", \
  "--set-xauthrequest=true"]
```

2. Push to GitHub

3. In Railway:
   - Click "New" → "GitHub Repo" → Select your repo
   - This creates a second service
   - In settings, set custom Dockerfile path: `Dockerfile.oauth2`

4. Set environment variables for OAuth2 Proxy service:
   ```
   DOMAIN=https://your-app.up.railway.app
   GOOGLE_CLIENT_ID=your-client-id
   GOOGLE_CLIENT_SECRET=your-client-secret
   OAUTH2_COOKIE_SECRET=your-cookie-secret
   OAUTH2_EMAIL_DOMAINS=*
   VAULTWARDEN_URL=http://vaultwarden.railway.internal
   ```

5. **Important**: Generate a Railway domain for the **OAuth2 Proxy service** (not Vaultwarden)
   - This will be your new public URL
   - Update `DOMAIN` variable to match this new URL

### Step 3.3: Update Google OAuth Redirect URI

Go back to Google Cloud Console and update the redirect URI to your new Railway domain:
```
https://your-new-oauth-proxy-url.up.railway.app/oauth2/callback
```

---

## Step 4: Test Authentication

1. Visit your Railway URL
2. You should be redirected to Google login
3. Sign in with an authorized Google account
4. After Google auth, you'll see Vaultwarden login
5. Log in with your master password

## Restrict Access

### Restrict to Specific Email Domain

Set environment variable:
```
OAUTH2_EMAIL_DOMAINS=yourdomain.com
```

Only `@yourdomain.com` emails can access.

### Restrict to Specific Emails

For more granular control, use authenticated emails file:

1. Create a file with allowed emails (one per line)
2. Mount it in the container
3. Add flag: `--authenticated-emails-file=/path/to/emails.txt`

## Security Considerations

### Pros
- ✅ Extra authentication layer before Vaultwarden
- ✅ SSO integration with Google
- ✅ Can restrict to specific Google Workspace domain
- ✅ Audit trail via Google login logs

### Cons
- ⚠️ Adds dependency on Google services
- ⚠️ More complex deployment
- ⚠️ May interfere with Bitwarden mobile apps

### Important Notes

1. **Mobile Apps May Not Work**: Bitwarden mobile apps may not support OAuth2 Proxy
   - Web vault will work fine
   - Browser extensions may work
   - Desktop apps may work
   - Test thoroughly!

2. **Admin Panel**: You'll need Google auth to access `/admin`

3. **API Access**: API clients will need to authenticate via OAuth2

## Alternative: Admin-Only OAuth

If you want OAuth only for the admin panel:

Use nginx or Caddy as reverse proxy with path-based rules:
- `/admin/*` → Requires OAuth
- `/*` → Direct to Vaultwarden

This is more complex but preserves app compatibility.

## Troubleshooting

### Redirect Loop
- Check `DOMAIN` variable matches your Railway URL exactly
- Ensure redirect URI in Google Console matches exactly

### "Unauthorized" Error
- Check `OAUTH2_EMAIL_DOMAINS` allows your email
- Verify email is in test users (if app not published)

### Can't Access After OAuth
- Check `VAULTWARDEN_URL` points to correct internal service
- Verify both services are running in Railway

### Mobile Apps Don't Work
- Expected behavior - OAuth2 Proxy blocks standard Bitwarden API
- Options:
  1. Use web vault only
  2. Deploy separate Vaultwarden without OAuth for apps
  3. Use different authentication method

## Environment Variables Reference

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `GOOGLE_CLIENT_ID` | Yes | From Google Console | `xxx.apps.googleusercontent.com` |
| `GOOGLE_CLIENT_SECRET` | Yes | From Google Console | `GOCSPX-xxx` |
| `OAUTH2_COOKIE_SECRET` | Yes | Random 32-byte base64 | Generate with openssl |
| `OAUTH2_EMAIL_DOMAINS` | No | Allowed email domains | `*` or `yourdomain.com` |
| `DOMAIN` | Yes | Your public URL | `https://app.railway.app` |
| `VAULTWARDEN_URL` | Yes (Option B) | Internal Vaultwarden URL | `http://vaultwarden.railway.internal` |

## Disabling OAuth

To disable and go back to Vaultwarden-only:

### Option A (Docker Compose)
Remove/comment out OAuth variables in `.env` and restart without oauth2-proxy service

### Option B (Railway)
Point your domain back to the Vaultwarden service instead of OAuth2 Proxy

## Resources

- [OAuth2 Proxy Docs](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Google OAuth Setup](https://developers.google.com/identity/protocols/oauth2)
- [Railway Networking](https://docs.railway.app/deploy/networking)

## Support

Having issues?
- Check Railway logs for both services
- Verify Google OAuth credentials
- Test with `OAUTH2_EMAIL_DOMAINS=*` first
- Check browser console for errors
