#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Run Oracle Root Scripts
# Run As:      ROOT
# =============================================

ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
ORACLE_INVENTORY=/u01/app/oraInventory
LOG_FILE="/tmp/oracle_root_$(date +%Y%m%d).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Running Oracle Database Root Scripts"
log_message "============================================"

# Run orainstRoot.sh (if not already run)
if [ -f "$ORACLE_INVENTORY/orainstRoot.sh" ]; then
    log_message "Running orainstRoot.sh..."
    $ORACLE_INVENTORY/orainstRoot.sh | tee -a $LOG_FILE
fi

# Run root.sh for Oracle Home
log_message "Running root.sh for Oracle Home..."
$ORACLE_HOME/root.sh | tee -a $LOG_FILE

log_message "✅ Oracle Root Scripts Complete"
