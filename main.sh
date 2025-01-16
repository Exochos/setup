#!/bin/bash
# main.sh --> Master script that orchestrates sub-scripts.
set -euo pipefail

# Source the shared environment
source "$(dirname "$0")/env.sh"

# If the user passed a domain argument (e.g., ./main.sh mydomain.com), override DOMAIN_NAME.
if [ $# -ge 1 ]; then
  export DOMAIN_NAME="$1"
fi

# Basic usage check if DOMAIN_NAME is still empty
if [ -z "$DOMAIN_NAME" ]; then
  echo "Usage: $0 <domain.com>"
  exit 1
fi

# Because EMAIL is derived from $DOMAIN_NAME in env.sh,
# we can re-export it to ensure it's in sync with the just-updated DOMAIN_NAME.
export EMAIL="admin@$DOMAIN_NAME"

echo "========================================"
echo "Running main script with domain: $DOMAIN_NAME"
echo "Email: $EMAIL"
echo "Monitoring port: $MONITORING_PORT"
echo "Log file: $LOG_FILE"
echo "Script version: $VERSION"
echo "========================================"

# Make sure sub-scripts are executable
chmod +x "$(dirname "$0")"/*.sh

# Call sub-scripts in the desired sequence
"$(dirname "$0")/preflight.sh"
"$(dirname "$0")/system_update.sh"
"$(dirname "$0")/swap.sh"
"$(dirname "$0")/nginx_setup.sh"
"$(dirname "$0")/certbot.sh"
"$(dirname "$0")/final_report.sh"

exit 0
