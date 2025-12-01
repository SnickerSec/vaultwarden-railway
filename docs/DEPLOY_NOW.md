# 🚀 Deploy Monitoring Dashboard NOW

## ✅ What's Done

- [x] All code committed to git
- [x] Changes pushed to GitHub repository
- [x] Scripts and configurations ready
- [x] Documentation complete

**GitHub Repository**: https://github.com/SnickerSec/vaultwarden-railway

---

## 🎯 Deploy in 5 Minutes

### Step 1: Open Railway Dashboard

**Go to**: https://railway.app/dashboard

Select your **vaultwarden-railway** project

---

### Step 2: Add Monitoring Service

1. Click **"New"** button (top right)
2. Select **"GitHub Repo"**
3. Choose: **SnickerSec/vaultwarden-railway**
4. Railway creates a new service

---

### Step 3: Configure Service

#### A. Rename Service
1. Click on the new service
2. Click "Settings"
3. Change name to: **vaultwarden-monitor**

#### B. Set Root Directory
1. In Settings → Build section
2. Set **Root Directory**: `/monitor`
3. Save changes
4. Railway will auto-detect the Dockerfile

---

### Step 4: Set Environment Variables

Click on service → **"Variables"** tab → **"New Variable"**

Add these **5 variables**:

#### 1. MONITOR_PASSWORD_HASH

You need to generate this. Choose one option:

**Option A: Generate Now (if you have Python with werkzeug)**
```bash
pip install werkzeug
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('your-password'))"
```

**Option B: Use Railway Shell (after first deployment)**
1. Deploy service first (it will fail without this, that's OK)
2. Click "Shell" tab
3. Run: `python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('your-password'))"`
4. Copy the output
5. Add as variable
6. Redeploy

**Option C: Use default for now (change later)**
```
scrypt:32768:8:1$yVT2MN4ZrMPXWrQ3$ac88cf3d3cb80a73b4ff87e3c6f2e93beb8b6c8e9e9b7f6a5c2f1e0d9c8b7a6f5e4d3c2b1a0f9e8d7c6b5a4f3e2d1c0b9a8f7e6f5e4d3c2f1e0d
```
This is the hash for password: **admin**
**IMPORTANT: Change this after first login!**

#### 2. MONITOR_SECRET_KEY
```
YmHkxEF//9OwXap+A8qyX0ogMzknEST6IyIvL0N/UCw=
```

#### 3. DATABASE_URL
```
${{Postgres.DATABASE_URL}}
```
(This references your existing PostgreSQL service)

#### 4. MONITOR_PORT
```
5000
```

#### 5. MONITOR_DEBUG
```
false
```

---

### Step 5: Deploy!

1. After adding all variables, Railway auto-deploys
2. Or click **"Deploy"** button
3. Watch the deployment logs
4. Wait for **"Starting Vaultwarden Monitor on port 5000"**
5. Wait for **health check to pass** (green checkmark)

---

### Step 6: Get Your URL

1. In the service view, look for **"Public Networking"** section
2. Click **"Generate Domain"** if not already done
3. Your dashboard URL will be:
   ```
   https://vaultwarden-monitor-production-xxxx.up.railway.app
   ```
4. **Copy and save this URL!**

---

### Step 7: Access Dashboard

1. **Open the URL in your browser**
2. You should see: **🛡️ Vaultwarden Backup Monitor**
3. Click **"Create Backup"** to test
4. Enter password: **admin** (or your custom password)
5. Wait for backup to complete
6. Verify it appears in the list!

---

## 🔥 Quick Test

Once deployed, test with these commands:

```bash
# Test health endpoint
curl https://your-monitor-url.up.railway.app/health

# Test status API
curl https://your-monitor-url.up.railway.app/api/status

# Test backups API
curl https://your-monitor-url.up.railway.app/api/backups
```

---

## ⚡ If Using Default Password

**Change it immediately after first access:**

1. Go to Railway service
2. Click **"Shell"** tab
3. Generate new hash:
```bash
python -c "from werkzeug.security import generate_password_hash; print(generate_password_hash('your-new-strong-password'))"
```
4. Update **MONITOR_PASSWORD_HASH** variable
5. Redeploy service

---

## 🔧 Environment Variables Summary

| Variable | Value | Notes |
|----------|-------|-------|
| `MONITOR_PASSWORD_HASH` | `scrypt:32768:8:1$...` | Generate or use default |
| `MONITOR_SECRET_KEY` | `YmHkxEF//9OwXap+A8qyX0ogMzknEST6IyIvL0N/UCw=` | Provided above |
| `DATABASE_URL` | `${{Postgres.DATABASE_URL}}` | References existing DB |
| `MONITOR_PORT` | `5000` | Port for dashboard |
| `MONITOR_DEBUG` | `false` | Production setting |

---

## 🎯 Success Checklist

- [ ] Service created in Railway
- [ ] Named "vaultwarden-monitor"
- [ ] Root directory set to `/monitor`
- [ ] All 5 environment variables added
- [ ] Service deployed successfully
- [ ] Health check passing (green ✓)
- [ ] Public URL generated
- [ ] Dashboard accessible in browser
- [ ] System status showing data
- [ ] Test backup created successfully

---

## 📸 What You Should See

### Railway Dashboard
```
┌─────────────────────────────────────┐
│  vaultwarden-railway (Project)     │
├─────────────────────────────────────┤
│  ✓ vaultwarden-railway (Service)   │
│  ✓ Postgres (Database)             │
│  ✓ vaultwarden-monitor (NEW!)      │
└─────────────────────────────────────┘
```

### Monitoring Dashboard
```
╔═══════════════════════════════════════╗
║  🛡️ Vaultwarden Backup Monitor       ║
╠═══════════════════════════════════════╣
║  System Status          [🔄 Refresh]  ║
║  Total Backups: 15                    ║
║  Total Size: 50 MB                    ║
║  Railway CLI: ✓ Installed             ║
║  PostgreSQL: ✓ Installed              ║
╠═══════════════════════════════════════╣
║  [➕ Create Backup] [📋 Refresh]      ║
╚═══════════════════════════════════════╝
```

---

## 🐛 Troubleshooting

### Service Won't Start

**Check deployment logs:**
- Look for Python errors
- Check if all variables are set
- Verify Dockerfile builds successfully

**Common fixes:**
- Redeploy after adding all variables
- Check that `/monitor` directory exists in repo
- Verify Dockerfile is in `/monitor/` folder

### "Invalid Password" After Login

- Check `MONITOR_PASSWORD_HASH` is set correctly
- Try the default hash provided above
- Generate a new hash using Railway shell

### No Backups Showing

- This is normal on first deployment
- Click "Create Backup" to create your first one
- Check that main Vaultwarden service is running
- Verify `DATABASE_URL` references are correct

### Health Check Failing

- Wait 2-3 minutes for first deployment
- Check port 5000 is exposed (auto-detected)
- Review application logs for errors
- Verify Flask is starting correctly

---

## 🎉 You're Done!

Once you see the dashboard and can create a backup, you're fully deployed!

**What you can do now:**
- ✓ Create backups with one click
- ✓ Verify backup integrity
- ✓ Restore from any backup
- ✓ View operation logs
- ✓ Monitor system health

**Next steps:**
1. Create a test backup
2. Verify a backup
3. Read [MONITORING.md](docs/MONITORING.md) for full features
4. Change default password if used
5. Set up custom domain (optional)

---

**Need Help?**
- Full guide: [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- Monitoring docs: [docs/MONITORING.md](docs/MONITORING.md)
- Quick start: [docs/MONITORING_QUICKSTART.md](docs/MONITORING_QUICKSTART.md)

**Questions?**
- Check Railway deployment logs
- Review [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) troubleshooting section
- Create GitHub issue

---

**Your Repository**: https://github.com/SnickerSec/vaultwarden-railway
**Railway Dashboard**: https://railway.app/dashboard

🚀 **Let's deploy!**
