#!/bin/bash
# nginx.sh --> Install Nginx, Configure 

set -euo pipefail
source "$(dirname "$0")/env.sh"

echo "=== 04_install_basics: Installing packages..." | tee -a "$LOG_FILE"

{
  apt-get install -y nginx
} 2>&1 | tee -a "$LOG_FILE"

echo "=== 04_install_basics: Done." | tee -a "$LOG_FILE"
