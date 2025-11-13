# Automatic Updates Guide

This deployment is configured to **automatically stay up-to-date** with the latest Vaultwarden releases.

## How Automatic Updates Work

### 1. Daily Version Checks (GitHub Actions)

A GitHub Actions workflow runs daily at 2 AM UTC to:
- Check Docker Hub for new Vaultwarden versions
- Compare against your current deployment
- Automatically trigger Railway deployment if update is available
- Create a notification issue in your repository

**Workflow file:** `.github/workflows/update-vaultwarden.yml`

### 2. Auto-Deploy on Git Push (Railway)

Railway is configured to:
- Monitor your GitHub repository for changes
- Automatically rebuild and deploy when commits are pushed
- Pull the latest `vaultwarden/server:latest` Docker image
- Zero-downtime deployment with health checks

**Configuration:** `railway.toml`

### 3. Weekly Version Reports

Every Monday at 9 AM UTC, a report is generated showing:
- Current deployed version
- Latest available version
- Recent version history
- Update status

**Workflow file:** `.github/workflows/check-version.yml`

## Update Methods

### Automatic (Recommended)
✅ Enabled by default - no action needed!

The system automatically:
1. Detects new versions daily
2. Pushes update commit to GitHub
3. Railway auto-deploys the update
4. Health checks ensure successful deployment

### Manual Updates

#### Method 1: GitHub Actions UI
1. Go to your repository on GitHub
2. Click "Actions" tab
3. Select "Check and Update Vaultwarden"
4. Click "Run workflow"
5. Railway will auto-deploy

#### Method 2: Git Commit
```bash
git commit --allow-empty -m "chore: rebuild for latest version"
git push
```

#### Method 3: Railway CLI
```bash
railway up --detach
```

#### Method 4: Railway Dashboard
1. Go to your Railway project
2. Click your service
3. Click "Deploy" → "Redeploy"

## Update Strategy

### Using `latest` Tag (Default - Always Current)
```dockerfile
FROM vaultwarden/server:latest
```

**Pros:**
- Always on the newest version
- Automatic updates with every rebuild
- No version tracking needed

**Cons:**
- Less control over specific versions
- Potential for unexpected changes

### Using Specific Version Tags (More Control)
```dockerfile
FROM vaultwarden/server:1.30.5
```

**Pros:**
- Predictable deployments
- Control over when to update
- Can test before updating

**Cons:**
- Requires manual version bumps
- May miss security updates

**To switch to specific versions:**
1. Edit `Dockerfile`
2. Change `latest` to specific version (e.g., `1.30.5`)
3. Commit and push
4. Update workflow to auto-bump version tags

## Monitoring Updates

### Check Current Version

**Via Railway Dashboard:**
1. Go to your service
2. Click "Deployments"
3. Check deployment logs for version info

**Via Railway CLI:**
```bash
railway logs
```

Look for startup logs showing Vaultwarden version.

**Via Web Interface:**
Visit `https://your-app.up.railway.app/` and check the footer or admin panel.

### GitHub Notifications

After automatic updates, check:
- **Actions tab**: View workflow run results
- **Issues**: Auto-created update notifications
- **Commits**: Auto-generated update commits

## Pre-Update Checklist

Before major updates (optional but recommended):

1. **Backup your vault**
   ```bash
   # Via web interface
   Tools → Export Vault → Save encrypted JSON
   ```

2. **Check release notes**
   - Visit: https://github.com/dani-garcia/vaultwarden/releases
   - Review breaking changes

3. **Test in staging** (advanced)
   - Deploy to separate Railway service
   - Test with backup data

## Post-Update Verification

After automatic updates:

1. **Check health status**
   ```bash
   curl https://your-app.up.railway.app/alive
   ```

2. **Test login**
   - Log into web vault
   - Verify 2FA works
   - Test password retrieval

3. **Check admin panel**
   - Visit `/admin`
   - Review diagnostics
   - Check for warnings

4. **Verify browser extensions**
   - Test auto-fill
   - Check sync functionality

## Rollback Procedure

If an update causes issues:

### Option 1: Railway Dashboard
1. Go to Deployments
2. Find previous working deployment
3. Click "Redeploy"

### Option 2: Git Revert
```bash
# Find the problematic commit
git log --oneline

# Revert to previous commit
git revert <commit-hash>
git push
```

### Option 3: Pin to Specific Version
```bash
# Edit Dockerfile
# Change: FROM vaultwarden/server:latest
# To: FROM vaultwarden/server:1.30.5 (working version)

git add Dockerfile
git commit -m "fix: rollback to stable version"
git push
```

## Update Schedule

| Check Type | Frequency | Action |
|------------|-----------|--------|
| Version Check | Daily @ 2 AM UTC | Auto-deploy if new version |
| Version Report | Weekly (Monday) | Generate status report |
| Manual Check | On-demand | Via GitHub Actions UI |

## Customizing Update Behavior

### Change Update Frequency

Edit `.github/workflows/update-vaultwarden.yml`:

```yaml
on:
  schedule:
    # Change to weekly: every Sunday at 2 AM
    - cron: '0 2 * * 0'
```

### Disable Automatic Updates

**Option 1: Keep checks, disable auto-deploy**

Edit `.github/workflows/update-vaultwarden.yml`:
Remove or comment out the "Trigger Railway deployment" step.

**Option 2: Disable workflow**

```bash
# Rename workflow file to disable it
mv .github/workflows/update-vaultwarden.yml .github/workflows/update-vaultwarden.yml.disabled
```

**Option 3: Use specific version tags**

Edit `Dockerfile` to use specific version instead of `latest`.

## Security Updates

Critical security updates are handled automatically:
- Daily checks catch security releases quickly
- Railway's auto-deploy ensures rapid deployment
- Health checks prevent broken deployments

**Emergency manual update:**
```bash
# Force immediate rebuild
git commit --allow-empty -m "security: emergency update"
git push
```

## Troubleshooting Updates

### Update not deploying

**Check GitHub Actions:**
```bash
# View in GitHub
Actions → Check and Update Vaultwarden → Latest run
```

**Common issues:**
- Workflow disabled
- Repository permissions
- Railway webhook not configured

### Railway not auto-deploying

**Verify Railway settings:**
1. Project Settings → Integrations
2. Check GitHub connection
3. Verify webhook is active

**Check railway.toml:**
```toml
[deploy.triggers]
gitPush = true
```

### Version stuck on old release

**Force rebuild:**
```bash
# Pull latest and force deploy
git commit --allow-empty -m "chore: force rebuild"
git push
```

**Check Docker cache:**
Railway rebuilds may use cached layers. The `latest` tag ensures fresh pulls.

## Best Practices

1. **Enable GitHub notifications** for workflow runs
2. **Monitor update issues** created by automation
3. **Review release notes** for breaking changes
4. **Keep backups** before major version jumps
5. **Test critical workflows** after updates
6. **Subscribe to Vaultwarden releases** on GitHub
7. **Check Railway logs** after auto-deploys

## Update Logs

Railway keeps deployment history:
- Last 100 deployments visible
- Full logs for each deployment
- Metrics and health check results

Access via:
- Railway Dashboard → Deployments
- Railway CLI: `railway logs --deployment <id>`

## Resources

- [Vaultwarden Releases](https://github.com/dani-garcia/vaultwarden/releases)
- [Docker Hub Tags](https://hub.docker.com/r/vaultwarden/server/tags)
- [Railway Docs - Auto Deployments](https://docs.railway.app/deploy/deployments)
- [GitHub Actions Docs](https://docs.github.com/en/actions)

## Support

Having issues with updates?

1. Check GitHub Actions logs
2. Review Railway deployment logs
3. Verify environment variables
4. Check Railway service health
5. Consult DEPLOY.md for troubleshooting
6. Open issue in your repository
