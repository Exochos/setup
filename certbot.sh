#!/bin/bash
# certbot.sh --> Obtain and Configure SSL Certificates with Certbot (Greenfield Installation)
set -euo pipefail
source "$(dirname "$0")/env.sh"

echo "=== 05_certbot: Setting up Certbot and obtaining SSL certificates..." | tee -a "$LOG_FILE"

{
    # Install Certbot and its Nginx plugin if not already installed
    if ! command -v certbot &> /dev/null; then
        echo "Installing Certbot and its Nginx plugin..." | tee -a "$LOG_FILE"
        apt-get update
        apt-get install -y certbot python3-certbot-nginx
    else
        echo "Certbot is already installed." | tee -a "$LOG_FILE"
    fi

    # Ensure Nginx is running
    if ! systemctl is-active --quiet nginx; then
        echo "Nginx is not running. Starting Nginx..." | tee -a "$LOG_FILE"
        systemctl start nginx
    fi

    # Obtain SSL certificate using Certbot
    echo "Obtaining SSL certificate for $DOMAIN_NAME and www.$DOMAIN_NAME..." | tee -a "$LOG_FILE"
    certbot --nginx -d "$DOMAIN_NAME" -d "www.$DOMAIN_NAME" --non-interactive --agree-tos --email "$EMAIL" --redirect

    # Test the renewal process
    echo "Testing certificate renewal process..." | tee -a "$LOG_FILE"
    certbot renew --dry-run

    # Configure automatic renewal
    echo "Configuring automatic certificate renewal..." | tee -a "$LOG_FILE"
    echo "0 0 * * * /usr/bin/certbot renew --quiet --post-hook 'systemctl reload nginx'" | tee /etc/cron.d/certbot-renewal

    # Restart Nginx to apply changes
    echo "Restarting Nginx to apply SSL configuration..." | tee -a "$LOG_FILE"
    systemctl reload nginx

} 2>&1 | tee -a "$LOG_FILE"

# Verify SSL certificate
if [ -f "/etc/letsencrypt/live/$DOMAIN_NAME/fullchain.pem" ]; then
    echo "SSL certificate obtained and configured successfully for $DOMAIN_NAME." | tee -a "$LOG_FILE"
else
    echo "Error: SSL certificate installation failed!" | tee -a "$LOG_FILE"
    exit 1
fi

echo "Done." | tee -a "$LOG_FILE"
