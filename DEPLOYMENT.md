# Deployment Guide - Digital Ocean

This guide walks you through deploying your BaeHub Rails app to Digital Ocean using Kamal.

## Prerequisites

- Docker installed locally
- SSH key set up (`~/.ssh/id_ed25519.pub`)
- Digital Ocean account
- Docker Hub account (or DO Container Registry)

## Step 1: Create Digital Ocean Droplet

1. **Log in to Digital Ocean**: https://cloud.digitalocean.com
2. **Create a Droplet**:
   - Click "Create" → "Droplets"
   - **Image**: Ubuntu 22.04 (LTS) x64
   - **Plan**: Basic Shared CPU
   - **CPU options**: Regular, 2 GB RAM / 1 CPU ($12/month minimum recommended)
   - **Datacenter region**: Choose closest to your users
   - **Authentication**: SSH keys
     - Add your public SSH key (run `cat ~/.ssh/id_ed25519.pub` to view it)
   - **Hostname**: baehub-web
   - Click "Create Droplet"

3. **Note your Droplet's IP address** (e.g., 164.90.XXX.XXX)

## Step 2: Configure Your Domain (Optional but Recommended)

If you have a domain:

1. Go to your domain registrar (Namecheap, GoDaddy, etc.)
2. Add an A record:
   - **Host**: @ (or your subdomain)
   - **Value**: Your droplet IP
   - **TTL**: 300 (5 minutes)

3. Wait for DNS propagation (5-30 minutes)

## Step 3: Update Deployment Configuration

1. **Edit `config/deploy.yml`** and replace:
   - `YOUR_DROPLET_IP_HERE` → Your actual droplet IP
   - `YOUR_DOCKER_USERNAME` → Your Docker Hub username (e.g., `johndoe`)

2. **If you want SSL/HTTPS** (recommended for production), uncomment and configure:

```yaml
proxy:
  ssl: true
  host: yourdomain.com
```

## Step 4: Set Up Docker Registry

### Option A: Docker Hub (Free, Recommended)

1. Create Docker Hub account at https://hub.docker.com
2. Create access token:
   - Go to Account Settings → Security → New Access Token
   - Name: "baehub-deploy"
   - Permissions: Read, Write, Delete
   - Copy the token

3. Login locally:
```bash
docker login
```

### Option B: Digital Ocean Container Registry

1. Create registry in DO dashboard
2. Install `doctl` CLI
3. Run: `doctl registry login`
4. Update `config/deploy.yml`:

```yaml
registry:
  server: registry.digitalocean.com/YOUR_REGISTRY_NAME
  username: YOUR_DO_USERNAME
  password:
    - KAMAL_REGISTRY_PASSWORD
```

## Step 5: Configure Secrets

1. **Edit `.kamal/secrets`** (already created)
2. **Get Docker Hub access token** (from Step 4)
3. **Update the file**:

```bash
#!/bin/sh

# Docker Hub access token
export KAMAL_REGISTRY_PASSWORD="dckr_pat_YOUR_ACCESS_TOKEN_HERE"

# Rails master key (auto-loaded from config/master.key)
export RAILS_MASTER_KEY="$(cat config/master.key)"
```

4. **Make it executable** (already done):
```bash
chmod +x .kamal/secrets
```

## Step 6: Prepare Your Server

Run the setup command to install Docker on your droplet:

```bash
bin/kamal setup
```

This will:
- Install Docker on the server
- Set up the application
- Create volumes for persistent storage
- Start the application

## Step 7: Deploy

For subsequent deployments:

```bash
bin/kamal deploy
```

This will:
- Build your Docker image
- Push to registry
- Pull on server
- Run database migrations
- Start/restart the app

## Useful Kamal Commands

```bash
# View logs
bin/kamal app logs -f

# Access Rails console
bin/kamal console

# SSH into server
bin/kamal app exec -i bash

# Access database console
bin/kamal dbc

# Check app status
bin/kamal app details

# Rollback to previous version
bin/kamal rollback

# Restart the app
bin/kamal app restart

# Stop the app
bin/kamal app stop

# Remove everything (careful!)
bin/kamal remove
```

## Post-Deployment Tasks

### 1. Create Admin User

```bash
bin/kamal console
# Then in Rails console:
User.create!(email: 'admin@example.com', password: 'securepassword', name: 'Admin')
```

### 2. Set Up Firewall (Recommended)

```bash
# SSH into your droplet
ssh root@YOUR_DROPLET_IP

# Configure UFW
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

### 3. Enable Automatic Updates

```bash
# On the droplet
apt update
apt install unattended-upgrades
dpkg-reconfigure -plow unattended-upgrades
```

## Production Environment Variables

To add environment variables:

1. Edit `config/deploy.yml` under the `env:` section
2. For secrets, add to `.kamal/secrets`
3. Redeploy: `bin/kamal deploy`

Example:

```yaml
env:
  secret:
    - RAILS_MASTER_KEY
    - SMTP_PASSWORD
  clear:
    SMTP_HOST: smtp.example.com
    SOLID_QUEUE_IN_PUMA: true
```

## Monitoring & Maintenance

### Check Disk Space
```bash
bin/kamal app exec "df -h"
```

### Clean Up Old Docker Images
```bash
bin/kamal app exec "docker system prune -af"
```

### View Resource Usage
```bash
bin/kamal app exec "docker stats --no-stream"
```

## Troubleshooting

### Can't connect to server
```bash
# Test SSH connection
ssh root@YOUR_DROPLET_IP

# Check if Docker is running
bin/kamal app exec "docker ps"
```

### App won't start
```bash
# Check logs
bin/kamal app logs

# Check for errors
bin/kamal app details
```

### Database issues
```bash
# Access Rails console
bin/kamal console

# Run migrations manually
bin/kamal app exec "bin/rails db:migrate"
```

### SSL certificate issues
- Make sure DNS is pointing to your droplet
- Wait for DNS propagation (check with: `dig yourdomain.com`)
- Kamal uses Traefik with Let's Encrypt automatically

## Scaling

### Add More Servers

Edit `config/deploy.yml`:

```yaml
servers:
  web:
    - 164.90.XXX.XXX
    - 164.90.YYY.YYY
```

### Separate Job Processing

```yaml
servers:
  web:
    - 164.90.XXX.XXX
  job:
    hosts:
      - 164.90.YYY.YYY
    cmd: bin/jobs
```

## Security Best Practices

1. **Use environment variables for all secrets**
2. **Enable firewall (UFW)**
3. **Keep system updated**
4. **Use strong passwords**
5. **Enable SSL/HTTPS**
6. **Regular backups** (use DigitalOcean snapshots)
7. **Monitor logs** regularly

## Backup Strategy

### SQLite Database Backup

The database is stored in the volume. To backup:

```bash
# On the droplet
docker run --rm -v baehub_web_storage:/source -v /backup:/backup ubuntu tar czf /backup/baehub-backup-$(date +%Y%m%d).tar.gz -C /source .
```

### Automated Backups

Use DigitalOcean's snapshot feature or set up a cron job on the server.

## Cost Estimate

- **Droplet**: $12-24/month (2-4 GB RAM)
- **Bandwidth**: Usually included
- **Backups**: $2.40/month (20% of droplet cost)
- **Domain**: $10-15/year
- **Total**: ~$15-30/month

## Support Resources

- Kamal Docs: https://kamal-deploy.org
- Rails Guides: https://guides.rubyonrails.org
- Digital Ocean Docs: https://docs.digitalocean.com
- Community: https://discuss.rubyonrails.org

## Next Steps

1. Replace placeholders in `config/deploy.yml`
2. Update `.kamal/secrets` with your Docker token
3. Run `bin/kamal setup`
4. Visit your app at `http://YOUR_DROPLET_IP`
5. Configure SSL if using a domain
6. Create your first user account

Good luck with your deployment! 🚀

