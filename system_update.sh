#!/bin/bash
# system_update.sh --> Updates system packages (apt update && apt upgrade)

set -euo pipefail
source "$(dirname "$0")/env.sh"

echo "=== 02_system_update: Updating system..." | tee -a "$LOG_FILE"

{
  apt update -y
  apt upgrade -y
} 2>&1 | tee -a "$LOG_FILE"

echo "=== 02_system_update: Done." | tee -a "$LOG_FILE"
