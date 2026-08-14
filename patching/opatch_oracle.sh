#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Apply Release Update (RU) patch
#              to Oracle Database Home
# Run As:      oracle user for opatch
#              root for root.sh
# =============================================

ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
ORACLE_SID=COMPANYDB
PATCH_DIR="/tmp/patches"
PATCH_NUMBER="35643107"
LOG_FILE="/tmp/patch_oracle_$(date +%Y%m%d_%H%M%S).log"

export ORACLE_HOME ORACLE_SID
export PATH=$ORACLE_HOME/bin:$PATH

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Applying Patch to Oracle Database Home"
log_message "Patch: $PATCH_NUMBER"
log_message "Oracle Home: $ORACLE_HOME"
log_message "============================================"

# -----------------------------------------------
# STEP 1: Shutdown Database
# -----------------------------------------------
log_message "Shutting down database: $ORACLE_SID..."

sqlplus -s / as sysdba << EOF | tee -a $LOG_FILE
    SHUTDOWN IMMEDIATE;
    EXIT;
EOF

log_message "✅ Database shutdown complete"

# -----------------------------------------------
# STEP 2: Stop Listener
# -----------------------------------------------
log_message "Stopping listener..."
lsnrctl stop | tee -a $LOG_FILE
log_message "✅ Listener stopped"

# -----------------------------------------------
# STEP 3: Apply Patch to Oracle Home
# -----------------------------------------------
log_message ""
log_message "Applying patch to Oracle Home..."

$ORACLE_HOME/OPatch/opatch apply \
    $PATCH_DIR/$PATCH_NUMBER \
    -oh $ORACLE_HOME \
    -silent \
    2>&1 | tee -a $LOG_FILE

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_message "✅ Oracle DB patch applied successfully"
else
    log_message "❌ Oracle DB patch FAILED"
    log_message "Starting database back..."
    sqlplus / as sysdba << EOF
        STARTUP;
        EXIT;
EOF
    lsnrctl start
    exit 1
fi

# -----------------------------------------------
# STEP 4: Start Database and Listener
# -----------------------------------------------
log_message ""
log_message "Starting listener..."
lsnrctl start | tee -a $LOG_FILE

log_message "Starting database..."
sqlplus -s / as sysdba << EOF | tee -a $LOG_FILE
    STARTUP;
    EXIT;
EOF

log_message "✅ Database and listener started"

log_message "============================================"
log_message "✅ Oracle Home Patching Complete"
log_message "NEXT STEP: Run DataPatch"
log_message "See: 04_datapatch.sh"
log_message "============================================"
