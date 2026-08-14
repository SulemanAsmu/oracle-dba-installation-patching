#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Run DataPatch to update
#              Oracle Database Dictionary
#              MUST run after every OPatch
#              Applies SQL changes to DB
# Run As:      oracle user
# =============================================

ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
ORACLE_SID=COMPANYDB
LOG_FILE="/tmp/datapatch_$(date +%Y%m%d_%H%M%S).log"

export ORACLE_HOME ORACLE_SID
export PATH=$ORACLE_HOME/bin:$PATH

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Running DataPatch"
log_message "Database: $ORACLE_SID"
log_message "============================================"

# -----------------------------------------------
# STEP 1: Verify Database is Open
# -----------------------------------------------
log_message "Checking database status..."

DB_STATUS=$(sqlplus -s / as sysdba << EOF
    SET PAGESIZE 0 FEEDBACK OFF
    SELECT STATUS FROM V\$INSTANCE;
    EXIT;
EOF
)

if echo "$DB_STATUS" | grep -q "OPEN"; then
    log_message "✅ Database is OPEN - ready for DataPatch"
else
    log_message "❌ Database is not OPEN - status: $DB_STATUS"
    exit 1
fi

# -----------------------------------------------
# STEP 2: Run DataPatch
# -----------------------------------------------
log_message ""
log_message "Running DataPatch..."
log_message "This updates the Oracle data dictionary..."

$ORACLE_HOME/OPatch/datapatch \
    -verbose \
    2>&1 | tee -a $LOG_FILE

if [ $? -eq 0 ]; then
    log_message "✅ DataPatch completed successfully"
else
    log_message "❌ DataPatch FAILED - check log: $LOG_FILE"
    exit 1
fi

# -----------------------------------------------
# STEP 3: Run utlrp to Recompile Invalid Objects
# -----------------------------------------------
log_message ""
log_message "Recompiling invalid database objects..."

sqlplus -s / as sysdba << EOF | tee -a $LOG_FILE

    -- Run utlrp to recompile invalid objects
    @?/rdbms/admin/utlrp.sql

    -- Check for remaining invalid objects
    SELECT
        COUNT(*) AS INVALID_OBJECTS
    FROM DBA_OBJECTS
    WHERE STATUS = 'INVALID';

    EXIT;
EOF

log_message "✅ Invalid objects recompiled"

# -----------------------------------------------
# STEP 4: Verify Patch in DBA_REGISTRY_SQLPATCH
# -----------------------------------------------
log_message ""
log_message "Verifying patches in database:"

sqlplus -s / as sysdba << EOF | tee -a $LOG_FILE

    -- Check patch status in database
    SELECT
        PATCH_ID,
        PATCH_UID,
        VERSION,
        STATUS,
        DESCRIPTION,
        TO_CHAR(ACTION_TIME,'DD-MON-YYYY HH24:MI:SS') AS APPLIED_TIME
    FROM DBA_REGISTRY_SQLPATCH
    ORDER BY ACTION_TIME DESC;

    -- Check registry components
    SELECT
        COMP_NAME,
        VERSION,
        STATUS
    FROM DBA_REGISTRY
    ORDER BY COMP_NAME;

    EXIT;
EOF

log_message "============================================"
log_message "✅ DataPatch Complete"
log_message "NEXT STEP: Verify patch with 05_patch_verify.sh"
log_message "============================================"
