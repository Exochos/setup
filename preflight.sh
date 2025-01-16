#!/bin/bash
# preflight.sh --> Pre-flight checks: user is root, dpkg not broken, DNS reminder, etc.
set -euo pipefail

source "$(dirname "$0")/env.sh"

echo "=== 01_preflight: Checking environment..." | tee -a "$LOG_FILE"

# Check root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root (use sudo)." | tee -a "$LOG_FILE"
  exit 1
fi

# Attempt to fix dpkg if interrupted
if ! dpkg --configure -a 2>/dev/null; then
  echo "Trying to fix 'dpkg was interrupted' automatically..." | tee -a "$LOG_FILE"
  dpkg --configure -a || {
    echo "Failed to fix dpkg automatically. Manual fix may be required." | tee -a "$LOG_FILE"
    exit 1
  }
fi

# DNS reminder
echo "IMPORTANT: Ensure DNS for $DOMAIN_NAME and www.$DOMAIN_NAME is pointed here before Certbot." | tee -a "$LOG_FILE"

echo "=== 01_preflight: Done." | tee -a "$LOG_FILE"
