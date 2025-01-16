#!/bin/bash
# env.sh --> Central config file for variables/flags used by sub-scripts.

# Exit on error, treat unset vars as errors, fail if any command in a pipeline fails
set -euo pipefail

: "${DOMAIN_NAME:=""}"
: "${EMAIL:="admin@$DOMAIN_NAME"}"
: "${MONITORING_PORT:="9991"}"
: "${LOG_FILE:="/var/log/server_setup.log"}"
: "${VERSION:="0.7"}"
