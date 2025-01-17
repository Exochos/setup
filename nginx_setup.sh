#!/bin/bash
# nginx.sh --> Install and Configure Nginx with Security Enhancements
set -euo pipefail
source "$(dirname "$0")/env.sh"
echo "=== 04_install_basics: Installing packages..." | tee -a "$LOG_FILE"
{
    # Update package list
    apt-get update

    # Install Nginx and supporting packages
    apt-get install -y nginx nginx-extras certbot python3-certbot-nginx apache2-utils fail2ban
    
    # Create Nginx cache directories
    mkdir -p /var/cache/nginx/proxy_cache
    chown -R www-data:www-data /var/cache/nginx/proxy_cache
    
    # Basic security configurations
    # Backup original nginx.conf
    cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup
    
    # Create basic security parameters
    cat > /etc/nginx/conf.d/security.conf << 'EOF'
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header X-Content-Type-Options "nosniff" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# Basic DoS mitigation
client_body_timeout 10s;
client_header_timeout 10s;
client_max_body_size 100M;
large_client_header_buffers 2 1k;

# File upload security
client_body_buffer_size 16k;
EOF

    # Configure fail2ban for Nginx
    cat > /etc/fail2ban/jail.d/nginx.conf << 'EOF'
[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3
findtime = 600
bantime = 3600

[nginx-bad-requests]
enabled = true
port = http,https
filter = nginx-bad-requests
logpath = /var/log/nginx/access.log
maxretry = 3
findtime = 600
bantime = 3600
EOF

    # Restart services
    systemctl enable nginx
    systemctl enable fail2ban
    systemctl restart fail2ban
    systemctl restart nginx

} 2>&1 | tee -a "$LOG_FILE"

# Verify installation
if systemctl is-active --quiet nginx; then
    echo "=== 04_install_basics: Nginx installed and running successfully." | tee -a "$LOG_FILE"
else
    echo "=== 04_install_basics: Error: Nginx installation failed!" | tee -a "$LOG_FILE"
    exit 1
fi

echo "=== 04_install_basics: Done." | tee -a "$LOG_FILE"
