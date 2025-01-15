# ░▒▓███████▓▒░▒▓████████▓▒░▒▓████████▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░ ░▒▓███████▓▒░▒▓█▓▒░░▒▓█▓▒░ 
#░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░ 
#░▒▓█▓▒░      ░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░ 
# ░▒▓██████▓▒░░▒▓██████▓▒░    ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓████████▓▒░ 
       #░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
       #░▒▓█▓▒░▒▓█▓▒░         ░▒▓█▓▒░   ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░▒▓██▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
#░▒▓███████▓▒░░▒▓████████▓▒░  ░▒▓█▓▒░    ░▒▓██████▓▒░░▒▓█▓▒░▒▓██▓▒░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░              
#!/bin/bash
# Usage:
# Git clone this repo -> chmod this file, run file in the form:
 # ./setup.sh yourdomain.com

DOMAIN_NAME=$1
EMAIL="admin@$DOMAIN_NAME"

if [ -z "$DOMAIN_NAME" ]; then
  echo "Usage: $0 yourdomain.com"
  exit 1
fi

# Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then 
  echo "Please run as root (use sudo)."
  exit 1
fi

# Update and upgrade the system
echo "Updating system..."
apt update && apt upgrade -y

# Create a swap file for low-memory instances
echo "Creating swap file..."
fallocate -l 4G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

# Make swap permanent
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab

# Optimize swap settings
echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
sysctl -p

# Install Nginx
echo "Installing Nginx..."
apt install nginx -y

# Configure UFW Firewall
echo "Configuring UFW firewall..."
ufw allow 'Nginx Full'
ufw allow OpenSSH

# Install Certbot for SSL
echo "Installing Certbot..."
apt install certbot python3-certbot-nginx -y

# Obtain SSL certificate
echo "Obtaining SSL certificate for $DOMAIN_NAME..."
certbot --nginx -d $DOMAIN_NAME -d www.$DOMAIN_NAME --non-interactive --agree-tos -m $EMAIL

# Install Node.js, npm, and PM2
echo "Installing Node.js, npm, and PM2..."
curl -sL https://deb.nodesource.com/setup_18.x | bash -
apt install -y nodejs
npm install -g pm2

# Set up Nginx server block
echo "Setting up Nginx configuration for $DOMAIN_NAME..."
if [ ! -f /etc/nginx/sites-available/$DOMAIN_NAME ]; then
  tee /etc/nginx/sites-available/$DOMAIN_NAME > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_NAME www.$DOMAIN_NAME;

    root /var/www/$DOMAIN_NAME/html;
    index index.html index.htm index.nginx-debian.html;

    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
else
  echo "Nginx configuration for $DOMAIN_NAME already exists. Skipping creation."
fi

# Enable site and restart Nginx
if [ ! -L /etc/nginx/sites-enabled/$DOMAIN_NAME ]; then
  ln -s /etc/nginx/sites-available/$DOMAIN_NAME /etc/nginx/sites-enabled/
fi

mkdir -p /var/www/$DOMAIN_NAME/html
if [ ! -f /var/www/$DOMAIN_NAME/html/index.html ]; then
  echo "<h1>Welcome to $DOMAIN_NAME</h1>" > /var/www/$DOMAIN_NAME/html/index.html
fi

nginx -t && systemctl restart nginx

# Enable PM2 startup
pm2 startup

# Reload UFW to apply any changes
ufw reload

echo "Web server setup complete for $DOMAIN_NAME! SSL is enabled, Nginx is configured, Node.js with PM2 is ready, and swap space is set up."
