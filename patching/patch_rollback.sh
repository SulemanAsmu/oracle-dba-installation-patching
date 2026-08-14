#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Rollback Oracle Patch
#              Use when patch causes issues
# Run As:      oracle user / root
# =============================================

GRID_HOME=/u01/app/19c/grid
ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
ORACLE_SID=COMPANYDB
PATCH_NUMBER="35643107"
LOG_FILE="/tmp/patch_rollback_$(date +%Y%m%d_%H%M%S).log"

export ORACLE_HOME ORACLE_SID
export PATH=$ORACLE_HOME/bin:$PATH

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "⚠️  ORACLE PATCH ROLLBACK"
log_message "Patch: $PATCH_NUMBER"
log_message "============================================"

read -p "Confirm ROLLBACK patch $PATCH_NUMBER? (YES/NO): " CONFIRM
[ "$CONFIRM" != "YES" ] && echo "Rollback cancelled" && exit 0

# -----------------------------------------------
# STEP 1: Rollback DataPatch Changes
# -----------------------------------------------
log_message "Rolling back DataPatch changes..."

sqlplus -s / as sysdba << EOF | tee -a $LOG_FILE
    -- Check current patch status
    SELECT PATCH_ID, STATUS FROM DBA_REGISTRY_SQLPATCH
    ORDER BY ACTION_TIME DESC;
    EXIT;
EOF

$ORACLE_HOME/OPatch/datapatch \
    -verbose \
    -rollback $PATCH_NUMBER \
    2>&1 | tee -a $LOG_FILE

log_message "✅ DataPatch rollback complete"

# -----------------------------------------------
# STEP 2: Shutdown Database
# -----------------------------------------------
log_message "Shutting down database..."

sqlplus -s / as sysdba << EOF
    SHUTDOWN IMMEDIATE;
    EXIT;
EOF

lsnrctl stop

# -----------------------------------------------
# STEP 3: Rollback OPatch from Oracle Home
# -----------------------------------------------
log_message ""
log_message "Rolling back patch from Oracle Home..."

$ORACLE_HOME/OPatch/opatch rollback \
    -id $PATCH_NUMBER \
    -oh $ORACLE_HOME \
    -silent \
    2>&1 | tee -a $LOG_FILE

log_message "✅ Oracle Home rollback complete"

# -----------------------------------------------
# STEP 4: Stop Grid and Rollback Grid Patch
# -----------------------------------------------
log_message ""
log_message "Stopping Grid services..."
$GRID_HOME/bin/crsctl stop has -f
sleep 15

log_message "Rolling back patch from Grid Home..."
su - grid -c "
    $GRID_HOME/OPatch/opatch rollback \
        -id $PATCH_NUMBER \
        -oh $GRID_HOME \
        -silent
" 2>&1 | tee -a $LOG_FILE

log_message "✅ Grid Home rollback complete"

# -----------------------------------------------
# STEP 5: Start Everything Back
# -----------------------------------------------
log_message ""
log_message "Starting Grid services..."
$GRID_HOME/bin/crsctl start has
sleep 30

log_message "Starting listener..."
lsnrctl start

log_message "Starting database..."
sqlplus -s / as sysdba << EOF
    STARTUP;
    EXIT;
EOF

# -----------------------------------------------
# STEP 6: Verify Rollback
# -----------------------------------------------
log_message ""
log_message "Verifying rollback..."

log_message "Grid patches after rollback:"
su - grid -c "$GRID_HOME/OPatch/opatch lspatches" | tee -a $LOG_FILE

log_message "Oracle patches after rollback:"
$ORACLE_HOME/OPatch/opatch lspatches | tee -a $LOG_FILE

log_message ""
log_message "Database status:"
sqlplus -s / as sysdba << EOF | tee -a $LOG_FILE
    SELECT VERSION_FULL, STATUS FROM V\$INSTANCE;
    EXIT;
EOF

log_message "============================================"
log_message "✅ Patch Rollback Complete"
log_message "============================================"
