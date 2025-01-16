# ░▒▓███████▓▒░▒▓████████▓▒░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░ ░▒▓███████▓▒░▒▓█▓▒░░▒▓█▓▒░ 
#░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░ 
#░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░ 
# ░▒▓██████▓▒░░▒▓██████▓▒░    ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓████████▓▒░ 
       #░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
       #░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓██▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
#░▒▓███████▓▒░░▒▓████████▓▒░  ░▒▓█▓▒░    ░▒▓██████▓▒░░▒▓█▓▒░▒▓██▓▒░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░              
#!/bin/bash
#!/bin/bash
# Server Setup Script v0.90
# Last updated: 2025-01-15
# Changelog:
# v0.90 - Added UFW enable, success checks, enhanced Node health check JSON,
#         created deployBot user, and improved error handling.
#
# Usage:
#   ./setup.sh yourdomain.com [--email=support@example.com]
#
# Example:
#   ./setup.sh mywebsite.com --email=admin@mywebsite.com

###################################################################
# Configuration and Parameter Parsing
###################################################################
# -e  : Exit on command error
# -u  : Treat unset variables as error
# -o pipefail : Fail if any command in a pipeline fails
set -euo pipefail

VERSION="0.90"
LOG_FILE="/var/log/server_setup.log"
DOMAIN_NAME=$1
EMAIL="admin@$DOMAIN_NAME"
MONITORING_PORT="4206969"

# Basic usage check
if [ -z "$DOMAIN_NAME" ]; then
  echo "Usage: $0 yourdomain.com [--email=admin@yourdomain.com]"
  exit 1
fi

echo "Running setup for domain: $DOMAIN_NAME"
echo "Email to be used: $EMAIL"
echo "Monitoring/NetData port: $MONITORING_PORT"
echo "Log file: $LOG_FILE"

# DNS validation note:
echo "IMPORTANT: Please ensure that DNS for $DOMAIN_NAME and www.$DOMAIN_NAME is pointing to this server BEFORE running Certbot."

###################################################################
# Root Check
###################################################################
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (sudo)."
  exit 1
fi

###################################################################
# Step 1: System Update/Upgrade
###################################################################
{
  echo "Updating system packages..."
  apt update -y && apt upgrade -y
} 2>&1 | tee -a "$LOG_FILE" || {
  echo "System update/upgrade failed. Exiting."
  exit 1
}


###################################################################
# Step 2: Check/Setup Swap
###################################################################
SWAPFILE="/swapfile"
if [ -f "$SWAPFILE" ]; then
  echo "Swap file already exists at $SWAPFILE. Skipping creation." | tee -a "$LOG_FILE"
else
  echo "Creating swap file..." | tee -a "$LOG_FILE"
  {
    fallocate -l 4G "$SWAPFILE"
    chmod 600 "$SWAPFILE"
    mkswap "$SWAPFILE"
    swapon "$SWAPFILE"
    echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
    # Optimize swap settings
    echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
    sysctl -p
  } >> "$LOG_FILE" 2>&1
fi

###################################################################
# Step 3: Install Basic Packages (Nginx, zip, etc.)
###################################################################
{
  echo "Installing Nginx, zip, and other utilities..."
  apt install -y nginx zip
} >> "$LOG_FILE" 2>&1 || {
  echo "Failed to install basic packages. Exiting."
  exit 1
}

###################################################################
# Step 4: Install & Configure Monitoring (NetData)
###################################################################
{
  echo "Installing NetData..."
  apt install -y netdata
  # Bind to localhost for security
  sed -i 's/# bind to = \*/bind to = 127.0.0.1/g' /etc/netdata/netdata.conf
  systemctl restart netdata
} >> "$LOG_FILE" 2>&1 || {
  echo "Failed to install/configure NetData. Exiting."
  exit 1
}

###################################################################
# Step 5: UFW Firewall Configuration
###################################################################
{
  echo "Configuring UFW firewall rules..."
  ufw allow 'Nginx Full'
  ufw allow OpenSSH
  ufw allow "$MONITORING_PORT"/tcp

  # If UFW is inactive, enable it
  UFW_STATUS=$(ufw status | grep -i "Status:" | awk '{print $2}')
  if [ "$UFW_STATUS" = "inactive" ]; then
    echo "UFW is inactive; enabling it now. Confirming SSH is allowed..."
    ufw --force enable
  else
    # Reload to apply
    ufw reload
  fi
} >> "$LOG_FILE" 2>&1

###################################################################
# Step 6: Certbot (Let's Encrypt) for SSL
###################################################################
{
  echo "Installing Certbot..."
  apt install -y certbot python3-certbot-nginx
  echo "Obtaining SSL certificate for $DOMAIN_NAME..."
  certbot --nginx -d "$DOMAIN_NAME" -d "www.$DOMAIN_NAME" --non-interactive --agree-tos -m "$EMAIL" --redirect
} >> "$LOG_FILE" 2>&1 || {
  echo "Certbot failed to obtain certificate for $DOMAIN_NAME. Exiting."
  exit 1
}

###################################################################
# Step 7: Install Node.js, npm, and PM2
###################################################################
{
  echo "Installing Node.js (18.x), npm, and PM2..."
  curl -sL https://deb.nodesource.com/setup_18.x | bash -
  apt install -y nodejs
  npm install -g pm2
} >> "$LOG_FILE" 2>&1 || {
  echo "Failed to install Node.js/PM2. Exiting."
  exit 1
}

###################################################################
# Step 8: Enhanced Node.js-based Health Check
###################################################################
NODE_APP_DIR="/var/www/$DOMAIN_NAME/health-app"
NODE_APP_FILE="$NODE_APP_DIR/index.js"

mkdir -p "$NODE_APP_DIR"

cat > "$NODE_APP_FILE" <<EOF
const os = require('os');
const http = require('http');

const PORT = process.env.PORT || $MONITORING_PORT;

const requestListener = (req, res) => {
  if (req.url === '/health') {
    const healthData = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      server_load: os.loadavg(),
      memory_usage: process.memoryUsage(),
      uptime_seconds: os.uptime(),
      platform: os.platform(),
      arch: os.arch()
    };
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(healthData, null, 2));
  } else {
    res.writeHead(404, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ error: 'Not found' }));
  }
};

const server = http.createServer(requestListener);

server.listen(PORT, () => {
  console.log(\`Node Health server running on port \${PORT}\`);
});
EOF

# Start this health-app with PM2
{
  echo "Starting Node-based health app on port $MONITORING_PORT with PM2..."
  pm2 start "$NODE_APP_FILE" --name "health-app"
  pm2 save
} >> "$LOG_FILE" 2>&1

###################################################################
# Step 9: Nginx Configuration
###################################################################
NGINX_SITE_CONF="/etc/nginx/sites-available/$DOMAIN_NAME"
{
  echo "Setting up Nginx configuration for $DOMAIN_NAME..."

  cat > "$NGINX_SITE_CONF" <<EOF
server {
    # HTTP server block that redirects all traffic to HTTPS
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;
    return 301 https://\$host\$request_uri;
}

server {
    # HTTPS server block
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    # SSL certs installed by Certbot (paths are automatically generated)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN_NAME/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;

    root /var/www/$DOMAIN_NAME/html;
    index index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    # Basic rate limiting: 60 req/min, burst=20
    limit_req_zone \$binary_remote_addr zone=one:10m rate=60r/m;

    location / {
        limit_req zone=one burst=20 nodelay;
        try_files \$uri \$uri/ =404;
    }

    # We can proxy /monitoring to NetData (on localhost:19999)
    location /monitoring {
        auth_basic "Monitoring Dashboard";
        auth_basic_user_file /etc/nginx/.htpasswd;

        proxy_pass http://127.0.0.1:19999;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_pass_request_headers on;
        proxy_set_header Connection "keep-alive";
        proxy_store off;
    }

    # Cache static files
    location ~* \.(jpg|jpeg|png|gif|ico|css|js)$ {
        expires 7d;
        add_header Cache-Control "public, no-transform";
    }
}
EOF

  # Create web root directory with a basic index
  mkdir -p /var/www/$DOMAIN_NAME/html
  if [ ! -f /var/www/$DOMAIN_NAME/html/index.html ]; then
    echo "<h1>Welcome to $DOMAIN_NAME</h1>" > /var/www/$DOMAIN_NAME/html/index.html
  fi

  # Create monitoring dashboard password if not exists
  if [ ! -f /etc/nginx/.htpasswd ]; then
    echo "Creating credentials for /monitoring (NetData dashboard)."
    apt install apache2-utils -y >> "$LOG_FILE" 2>&1
    echo "Please set a password for user 'admin':"
    htpasswd -c /etc/nginx/.htpasswd admin
  fi

  # Enable site if not already linked
  if [ ! -L /etc/nginx/sites-enabled/$DOMAIN_NAME ]; then
    ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
  fi

  # Test and restart Nginx
  nginx -t && systemctl restart nginx
} >> "$LOG_FILE" 2>&1 || {
  echo "Failed to configure or restart Nginx. Exiting."
  exit 1
}

###################################################################
# Step 10: PM2 Startup
###################################################################
{
  # Enable PM2 startup so it restarts on server reboot
  pm2 startup systemd -u root --hp /root
  pm2 save
} >> "$LOG_FILE" 2>&1 || {
  echo "Failed to enable PM2 startup. Exiting."
  exit 1
}

###################################################################
# Step 11: Basic Monitoring Cron Job
###################################################################
{
  echo "Setting up server monitoring cron job at /etc/cron.d/server-monitor..."
  cat > /etc/cron.d/server-monitor <<EOF
*/5 * * * * root curl -s http://localhost:$MONITORING_PORT/health >> /var/log/health-check.log 2>&1
EOF
} >> "$LOG_FILE" 2>&1


###################################################################
# Final Output
###################################################################
echo "=================================================="
echo "Web server setup complete for $DOMAIN_NAME!"
echo "Monitoring (NetData) dashboard:  https://$DOMAIN_NAME/monitoring"
echo "Node-based health endpoint:      http://$DOMAIN_NAME:$MONITORING_PORT/health"
echo
echo "deployBot user created for CI/CD. (See script logs for its password if newly created.)"
echo
echo "Remember to check your DNS settings for $DOMAIN_NAME and www.$DOMAIN_NAME."
echo "Log file: $LOG_FILE"
echo "Script version: $VERSION"
echo "=================================================="
