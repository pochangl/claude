---
name: deploy-server
description: Use this skill to set up a fresh server for deploying a project. Handles SSH access, git, deploy keys, cloning, runtime environment, nginx with SSL, webhook auto-deploy, and initial service startup. Triggers on mentions of "deploy server", "setup server", "provision server", "server setup", or "/deploy-server".
user-invocable: true
---

# Server Deployment Setup

Interactive skill that walks through setting up a fresh server (Amazon Linux / AL2023) to deploy and auto-redeploy a project via GitHub webhooks.

## Prerequisites

- SSH access to the server configured in `~/.ssh/config` (ask the user for the host alias)
- A GitHub repository to deploy
- A domain name pointed at the server's IP

## Procedure

Work through each phase in order. Run commands on the server via `ssh <host>`. Ask the user for input when noted.

### Phase 1: System Basics

1. **Ask the user** for:
   - SSH host alias (e.g., `sealroute`)
   - GitHub repo URL (e.g., `git@github.com:user/repo.git`)
   - Domain name (e.g., `route.sealersoft.com`)
   - User's email (for certbot — check CLAUDE.md or memory for known email)
2. SSH into the server and install git:
   ```bash
   ssh <host> "sudo dnf install -y git"
   ```

### Phase 2: Deploy Key

1. Generate an SSH keypair on the server (no passphrase):
   ```bash
   ssh <host> "ssh-keygen -t ed25519 -C 'deploy-key' -f ~/.ssh/id_ed25519 -N ''"
   ```
2. Print the public key:
   ```bash
   ssh <host> "cat ~/.ssh/id_ed25519.pub"
   ```
3. **Tell the user** to add the public key as a **Deploy Key** on GitHub:
   - Go to **Repo → Settings → Deploy keys → Add deploy key**
   - Paste the public key
   - Title: server hostname or alias
   - Check "Allow write access" only if needed
4. **Wait for the user** to confirm they've added the key before proceeding.
5. Test SSH access to GitHub:
   ```bash
   ssh <host> "ssh -T git@github.com 2>&1 || true"
   ```

### Phase 3: Clone Repository

1. Clone the repo into the home directory:
   ```bash
   ssh <host> "git clone <repo-url>"
   ```
2. Verify:
   ```bash
   ssh <host> "ls ~/$(basename <repo-url> .git)"
   ```

### Phase 4: Runtime Environment

Inspect the project to determine what runtime is needed (Docker, Node, Python, etc.) and install accordingly.

**If the project uses Docker** (has a `docker-compose.yml` or `Dockerfile`):

1. Install Docker:
   ```bash
   ssh <host> "sudo dnf install -y docker && sudo systemctl enable --now docker && sudo usermod -aG docker \$(whoami)"
   ```
2. Install Docker Compose plugin:
   ```bash
   ssh <host> "sudo mkdir -p /usr/local/lib/docker/cli-plugins && ..."
   ```
3. Install Docker Buildx plugin (required for `docker compose build`):
   ```bash
   ssh <host> "sudo mkdir -p /usr/local/lib/docker/cli-plugins && ..."
   ```
   Use the correct release URL format: `buildx-<version>.linux-<arch>` where arch is `amd64` or `arm64`.
4. Log out and back in (or `newgrp docker`) for the docker group to take effect.

**If the project uses Node.js** (no Docker):
- Install nvm and the required Node version.

**If the project uses Python** (no Docker):
- Install Python, create a venv, install requirements.

Adapt to whatever the project actually needs.

### Phase 5: Environment Variables

1. Generate a secret key:
   ```bash
   openssl rand -hex 32
   ```
2. Create a `.env` file in the project directory with the generated secret key and any other required environment variables. Check the project's `docker-compose.yml`, `settings.py`, or equivalent for what's needed.

### Phase 6: Nginx + SSL

1. Install nginx:
   ```bash
   ssh <host> "sudo dnf install -y nginx"
   ```
2. Write the nginx config that reverse proxies to the application. Include a `/hooks/` location for the webhook:
   ```nginx
   location /hooks/ {
       proxy_pass http://127.0.0.1:9000;
       proxy_request_buffering off;
       proxy_set_header Host $host;
       proxy_set_header X-Real-IP $remote_addr;
       proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
       proxy_set_header X-Forwarded-Proto $scheme;
   }
   ```
3. Remove the default nginx config if it conflicts.
4. Test and start nginx.
5. Install certbot and request an SSL certificate:
   ```bash
   ssh <host> "sudo dnf install -y certbot python3-certbot-nginx"
   ssh <host> "sudo certbot --nginx -d <domain> --non-interactive --agree-tos -m <email>"
   ```
6. Enable auto-renewal:
   ```bash
   ssh <host> "sudo systemctl enable --now certbot-renew.timer"
   ```

### Phase 7: Initial Build & Start

1. Build and start the application:
   ```bash
   ssh <host> "cd ~/repo && docker compose up -d"
   ```
   Or whatever the project's build/start command is.
2. Run migrations if applicable:
   ```bash
   ssh <host> "cd ~/repo && docker compose exec -T backend python manage.py migrate --noinput"
   ```
3. Run seed data if applicable.

### Phase 8: Webhook Auto-Deploy

1. Install the webhook binary (from [adnanh/webhook](https://github.com/adnanh/webhook) releases).
2. Generate a webhook secret or ask the user for one.
3. Write `/etc/webhook/hooks.json` with HMAC-SHA256 validation and branch filtering.
4. Write the deploy script at `/opt/deploy.sh`. **Important:**
   - Set `export HOME="/home/<user>"` so git SSH can find the deploy key.
   - Include: `git fetch`, `git reset --hard`, build, restart services, migrate, prune old images.
   - Add a `flock` concurrency guard.
   - Log to `/var/log/webhook/deploy.log`.
5. Write a systemd service for the webhook listener. **Important:**
   - Set `SupplementaryGroups=docker` if Docker is used.
   - Set `User=<deploy-user>`.
6. Enable and start the service.
7. Add logrotate config for webhook logs.

### Phase 9: Verify & Instruct

1. Test the webhook endpoint:
   ```bash
   SECRET="<secret>"
   BODY='{"ref":"refs/heads/main"}'
   SIG=$(echo -n "$BODY" | openssl dgst -sha256 -hmac "$SECRET" | cut -d' ' -f2)
   curl -s -X POST https://<domain>/hooks/deploy \
     -H "Content-Type: application/json" \
     -H "X-Hub-Signature-256: sha256=$SIG" \
     -d "$BODY"
   ```
2. **Tell the user** to set up the GitHub webhook:
   - Go to **Repo → Settings → Webhooks → Add webhook**
   - **Payload URL**: `https://<domain>/hooks/deploy`
   - **Content type**: `application/json` (IMPORTANT: must be JSON, not form-urlencoded)
   - **Secret**: the webhook secret
   - **Events**: Just the push event
   - **SSL verification**: Enabled

## Common Issues

- **`parameter node not found: ref`**: GitHub content type is set to `application/x-www-form-urlencoded` instead of `application/json`.
- **`failed to connect to socket`**: Add `SupplementaryGroups=docker` to the webhook systemd service.
- **`git fetch` fails silently**: The deploy script is missing `export HOME=...`, so SSH can't find the key.
- **Nginx `\$` in config**: When writing nginx config via bash heredoc, use `\$` for nginx variables. If writing the config file directly, use `$`.

## Lessons Learned (SealRouting deploy, 2026-04-15)

1. **Buildx download URL**: The release asset format is `buildx-v0.33.0.linux-amd64`, not `buildx-v0.33.0.linux-x86_64`. Must map `uname -m` to `amd64`/`arm64`.
2. **HOME not set in systemd**: The webhook systemd service doesn't set `HOME`, so `git fetch` over SSH silently fails because it can't find `~/.ssh/id_rsa`. Fixed by adding `export HOME="/home/<user>"` to the deploy script.
3. **Docker socket permission**: The webhook service runs as the deploy user but doesn't inherit the `docker` group from the login session. Fixed by adding `SupplementaryGroups=docker` to the systemd unit.
4. **GitHub webhook content type**: Default is `application/x-www-form-urlencoded`, which wraps the payload in a `payload=` form field. The webhook binary can't find `ref` in that format. Must be set to `application/json`.
5. **Nginx escaping through certbot**: When the setup script writes nginx config via heredoc with `\$` escapes, and the user later manually adds a `/hooks/` location by copying from the script output, the `\$` literals end up in the config file, causing `400 Bad Request: malformed Host header`.
6. **Nginx request body buffering**: Large GitHub payloads get buffered to a temp file. Adding `proxy_request_buffering off;` to the `/hooks/` location avoids this.
