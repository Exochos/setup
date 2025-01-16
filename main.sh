#!/bin/bash
# main.sh --> Master script that orchestrates all the sub-scripts.
set -euo pipefail

# We might parse the domain/email arguments here
DOMAIN_NAME="${1:-}"
if [ -z "$DOMAIN_NAME" ]; then
  echo "Usage: $0 yourdomain.com
  exit 1
fi

EMAIL="admin@$DOMAIN_NAME"


# Export so that sub-scripts can read these
export DOMAIN_NAME
export EMAIL

# Adjust or keep defaults
export LOG_FILE="/var/log/server_setup.log"
export VERSION="1.0"

# Source env.sh so sub-scripts can also rely on shared environment
source "$(dirname "$0")/env.sh"

chmod +x "$(dirname "$0")"/*.sh

# Pre-flight checks
"$(dirname "$0")/01_preflight.sh"

# System update
"$(dirname "$0")/02_system_update.sh"

# Swap setup
"$(dirname "$0")/03_swap.sh"

# Nginx Install && config
"$(dirname "$0")/09_nginx_config.sh"

# SSL (Certbot)
"$(dirname "$0")/06_certbot.sh"

# Final report
"$(dirname "$0")/99_final_report.sh"

exit 0
