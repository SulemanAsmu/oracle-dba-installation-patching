#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Run Grid Root Scripts
#              Must run as ROOT user
# Run As:      ROOT
# =============================================

ORACLE_HOME=/u01/app/19c/grid
ORACLE_INVENTORY=/u01/app/oraInventory
LOG_FILE="/tmp/grid_root_$(date +%Y%m%d_%H%M%S).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Running Grid Infrastructure Root Scripts"
log_message "============================================"

# -----------------------------------------------
# STEP 1: Run orainstRoot.sh
#         Sets up Oracle Inventory
# -----------------------------------------------
log_message "Running orainstRoot.sh..."

if [ -f "$ORACLE_INVENTORY/orainstRoot.sh" ]; then
    $ORACLE_INVENTORY/orainstRoot.sh | tee -a $LOG_FILE
    log_message "✅ orainstRoot.sh completed"
else
    log_message "⚠️  orainstRoot.sh not found at $ORACLE_INVENTORY"
fi

# -----------------------------------------------
# STEP 2: Run root.sh for Grid Home
#         This configures Oracle Restart and ASM
# -----------------------------------------------
log_message ""
log_message "Running root.sh for Grid Infrastructure..."
log_message "This starts Oracle Restart services..."

$ORACLE_HOME/root.sh | tee -a $LOG_FILE

if [ $? -eq 0 ]; then
    log_message "✅ root.sh completed successfully"
else
    log_message "❌ root.sh failed - check log"
    exit 1
fi

# -----------------------------------------------
# STEP 3: Run gridSetup.sh -executeConfigTools
# -----------------------------------------------
log_message ""
log_message "Running configuration tools..."

su - grid -c "$ORACLE_HOME/gridSetup.sh \
    -silent \
    -executeConfigTools \
    -responseFile /tmp/grid_install.rsp \
    -ignorePrereqFailure" | tee -a $LOG_FILE

log_message "✅ Configuration tools completed"

# -----------------------------------------------
# STEP 4: Verify Grid is Running
# -----------------------------------------------
log_message ""
log_message "Verifying Grid Infrastructure Status..."

su - grid -c "crsctl status resource -t" | tee -a $LOG_FILE

log_message "============================================"
log_message "✅ Grid Root Scripts Completed"
log_message "NEXT STEP: Run 04_grid_configuration.sh"
log_message "============================================"
