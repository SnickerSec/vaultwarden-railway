# Cloudflare Access Control Setup

Restrict your Vaultwarden instance to only your devices using Cloudflare's firewall.

## Why Cloudflare?

- ✅ Simple setup (15 minutes)
- ✅ Works with all Bitwarden apps (mobile, desktop, web)
- ✅ Free tier available
- ✅ No VPN needed
- ✅ Protects against DDoS
- ✅ Faster global performance

## Prerequisites

- Domain name (e.g., `yourdomain.com`)
- Cloudflare account (free)
- Railway deployment running

## Step 1: Add Domain to Cloudflare

1. Go to https://dash.cloudflare.com
2. Click "Add a Site"
3. Enter your domain name
4. Choose "Free" plan
5. Copy the Cloudflare nameservers (e.g., `ns1.cloudflare.com`)

## Step 2: Update Domain Nameservers

Go to your domain registrar (where you bought the domain) and change nameservers to Cloudflare's:

**Common registrars:**
- **Namecheap**: Domain List → Manage → Nameservers → Custom DNS
- **GoDaddy**: DNS → Nameservers → Change → Custom
- **Google Domains**: DNS → Name servers → Custom name servers

**Wait 5-60 minutes** for DNS propagation.

## Step 3: Add DNS Record for Railway

1. In Cloudflare dashboard, go to **DNS** → **Records**
2. Click **Add record**
3. Configure:
   ```
   Type: CNAME
   Name: vault (or whatever subdomain you want)
   Target: your-app.up.railway.app
   Proxy status: Proxied (orange cloud ☁️)
   TTL: Auto
   ```
4. Click **Save**

**Your Vaultwarden will be at:** `https://vault.yourdomain.com`

## Step 4: Update Railway Domain

1. Go to Railway dashboard
2. Click your Vaultwarden service
3. Go to **Settings** → **Networking**
4. Add custom domain: `vault.yourdomain.com`
5. Update environment variable:
   ```
   DOMAIN=https://vault.yourdomain.com
   ```

## Step 5: Restrict Access to Your Devices

### Option A: Block All Except Your IPs (Recommended)

1. In Cloudflare, go to **Security** → **WAF**
2. Click **Create rule**
3. Configure:
   ```
   Rule name: Allow only my devices

   Field: IP Source Address
   Operator: does not equal
   Value: YOUR_HOME_IP

   AND

   Field: IP Source Address
   Operator: does not equal
   Value: YOUR_MOBILE_IP

   Then: Block
   ```
4. Click **Deploy**

### Option B: Allow Only Your IPs (Simpler)

Create rule with:
```
Field: IP Source Address
Operator: is in list
Value: YOUR_HOME_IP, YOUR_MOBILE_IP, YOUR_WORK_IP

Then: Allow
```

Then create a second rule:
```
Match everything else
Then: Block
```

### Getting Your IP Addresses

**Home/Current IP:**
```bash
curl ifconfig.me
```
Or visit: https://whatismyip.com

**Mobile IP:**
- Connect to mobile data (not WiFi)
- Visit: https://whatismyip.com
- Note: Mobile IPs may change, see alternatives below

## Step 6: Test Access

1. Visit `https://vault.yourdomain.com`
2. Should work from allowed IPs
3. Test from different device/network - should be blocked

## Handling Mobile IP Changes

Mobile carrier IPs change frequently. Solutions:

### Solution 1: Allow IP Ranges
Get your carrier's IP ranges and allow the entire range.

**Example for T-Mobile US:**
```
Field: IP Source Address
Operator: is in
Value: 172.32.0.0/11
```

Find your carrier's ranges at: https://ipinfo.io/

### Solution 2: Use VPN on Mobile
- Install VPN app (Tailscale, ProtonVPN, etc.)
- VPN gives static IP
- Allow VPN IP in Cloudflare

### Solution 3: Cloudflare Access (Better)
Use Cloudflare Access for identity-based authentication instead of IP:

1. Go to **Zero Trust** → **Access** → **Applications**
2. Click **Add an application**
3. Choose **Self-hosted**
4. Configure:
   ```
   Application name: Vaultwarden
   Domain: vault.yourdomain.com
   ```
5. Add policy:
   ```
   Rule name: Allow my email
   Include: Emails ending in @gmail.com
   ```
6. Save

**Note:** This requires Cloudflare Zero Trust (free tier available).

## Advanced: Cloudflare Access with Email

For better mobile support, use email authentication:

1. **Cloudflare Zero Trust** (free tier)
2. Go to **Access** → **Applications**
3. Add application: `vault.yourdomain.com`
4. Create policy:
   ```
   Policy name: My Devices
   Action: Allow
   Include:
     - Emails: your-email@gmail.com
   ```
5. Choose authentication method: **One-time PIN**

**How it works:**
1. Visit vault.yourdomain.com
2. Enter your email
3. Receive PIN code
4. Enter PIN
5. Access granted for 24 hours

**Pros:** Works on any network, no IP management
**Cons:** Extra login step (but only once per day)

## Cloudflare Settings Optimization

### SSL/TLS Settings
1. Go to **SSL/TLS** → **Overview**
2. Set mode to: **Full (strict)**

### Security Level
1. Go to **Security** → **Settings**
2. Set Security Level: **High**
3. Enable **Bot Fight Mode**

### Speed Optimization
1. Go to **Speed** → **Optimization**
2. Enable **Auto Minify** (HTML, CSS, JS)
3. Enable **Brotli**

## Cost

**Cloudflare Free Tier includes:**
- ✅ DNS management
- ✅ SSL certificate
- ✅ Basic DDoS protection
- ✅ WAF rules (5 custom rules)
- ✅ Page Rules (3 rules)
- ✅ CDN caching

**Cloudflare Zero Trust Free Tier includes:**
- ✅ Up to 50 users
- ✅ Email authentication
- ✅ Access policies

**Total cost:** $0/month (free tier)

## Troubleshooting

### Can't access from allowed IP
- Clear browser cache
- Check IP hasn't changed: `curl ifconfig.me`
- Verify Cloudflare rule is active
- Check rule order (allow rules before block rules)

### SSL errors
- Ensure Railway has custom domain configured
- Set Cloudflare SSL mode to "Full (strict)"
- Wait a few minutes for certificate provisioning

### Mobile apps not working
- Ensure orange cloud (proxy) is enabled
- Check mobile IP is allowed
- Try Cloudflare Access instead of IP filtering

### Access blocked unexpectedly
- IP may have changed
- Check Cloudflare firewall events
- Temporarily disable rules to test

## Example Configuration

**For single user with home + mobile:**

**Cloudflare WAF Rule:**
```
Rule name: Allow my devices
Expression:
  (ip.src eq 1.2.3.4) or
  (ip.src in {172.32.0.0/11}) or
  (cf.bot_management.score gt 30)
Action: Skip → All remaining rules

Rule name: Block everyone else
Expression: true
Action: Block
```

**For family (multiple users):**
Use Cloudflare Access with email list instead of IP filtering.

## Security Best Practices

1. ✅ Use Cloudflare proxy (orange cloud)
2. ✅ Enable Bot Fight Mode
3. ✅ Set security level to High
4. ✅ Use Full (strict) SSL mode
5. ✅ Regularly review firewall events
6. ✅ Keep IP allowlist updated
7. ✅ Enable Cloudflare email notifications

## Migration from Railway URL

After Cloudflare setup:

1. **Update DOMAIN variable** in Railway to your custom domain
2. **Update Bitwarden apps**:
   - Open app settings
   - Change server URL to `https://vault.yourdomain.com`
   - Re-login
3. **Update browser extensions** similarly

## Quick Setup Checklist

- [ ] Domain added to Cloudflare
- [ ] Nameservers updated at registrar
- [ ] DNS record created (CNAME, proxied)
- [ ] Custom domain added in Railway
- [ ] DOMAIN env variable updated
- [ ] SSL mode set to Full (strict)
- [ ] WAF rule created with your IPs
- [ ] Tested access from allowed IP
- [ ] Tested blocked access from other IP
- [ ] Bitwarden apps updated with new URL

## Summary

**Simple IP restriction:**
- Add domain to Cloudflare
- Create CNAME to Railway
- Add WAF rule with your IPs
- Block all others

**Time:** 15 minutes
**Cost:** Free
**Maintenance:** Update IPs when they change

For questions, see main documentation or Cloudflare's guides:
https://developers.cloudflare.com/waf/
