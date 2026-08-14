#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Patch Verification Script
#              Run AFTER patching to confirm
#              everything is working
# =============================================

GRID_HOME=/u01/app/19c/grid
ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
ORACLE_SID=COMPANYDB
EXPECTED_VERSION="19.21.0.0.0"    # Expected after patch
LOG_FILE="/tmp/patch_verify_$(date +%Y%m%d).log"

export ORACLE_HOME ORACLE_SID
export PATH=$ORACLE_HOME/bin:$PATH

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

PASS=0
FAIL=0

check_pass() {
    echo "✅ [PASS] $1" | tee -a $LOG_FILE
    ((PASS++))
}

check_fail() {
    echo "❌ [FAIL] $1" | tee -a $LOG_FILE
    ((FAIL++))
}

log_message "============================================"
log_message "Patch Verification Report"
log_message "Date: $(date)"
log_message "Expected Version: $EXPECTED_VERSION"
log_message "============================================"

# -----------------------------------------------
# CHECK 1: Grid Home Patches
# -----------------------------------------------
log_message ""
log_message "=== Grid Home Patches ==="
su - grid -c "$GRID_HOME/OPatch/opatch lspatches" | tee -a $LOG_FILE

GI_VER=$(su - grid -c "$GRID_HOME/OPatch/opatch lsinventory" \
    | grep "Oracle Grid Infrastructure" \
    | head -1)
log_message "Grid Version: $GI_VER"

# -----------------------------------------------
# CHECK 2: Oracle Home Patches
# -----------------------------------------------
log_message ""
log_message "=== Oracle Home Patches ==="
$ORACLE_HOME/OPatch/opatch lspatches | tee -a $LOG_FILE

# -----------------------------------------------
# CHECK 3: Database Version
# -----------------------------------------------
log_message ""
log_message "=== Database Version ==="

DB_VERSION=$(sqlplus -s / as sysdba << EOF
    SET PAGESIZE 0 FEEDBACK OFF
    SELECT VERSION_FULL FROM V\$INSTANCE;
    EXIT;
EOF
)
log_message "DB Version: $DB_VERSION"

if echo "$DB_VERSION" | grep -q "$EXPECTED_VERSION"; then
    check_pass "Database version is $EXPECTED_VERSION"
else
    check_fail "Database version mismatch. Got: $DB_VERSION"
fi

# -----------------------------------------------
# CHECK 4: Database Status
# -----------------------------------------------
log_message ""
log_message "=== Database Status ==="

sqlplus -s / as sysdba << EOF | tee -a $LOG_FILE
    SET LINESIZE 200 PAGESIZE 50
    COL NAME FORMAT A15
    COL STATUS FORMAT A12
    COL OPEN_MODE FORMAT A15

    SELECT NAME, STATUS, OPEN_MODE FROM V\$DATABASE;

    -- Check component versions
    SELECT COMP_NAME, VERSION, STATUS
    FROM DBA_REGISTRY
    ORDER BY COMP_NAME;

    -- Check invalid objects
    SELECT COUNT(*) AS INVALID_OBJECTS
    FROM DBA_OBJECTS
    WHERE STATUS = 'INVALID';

    -- Check DataPatch status
    SELECT PATCH_ID, VERSION, STATUS, DESCRIPTION
    FROM DBA_REGISTRY_SQLPATCH
    ORDER BY ACTION_TIME DESC
    FETCH FIRST 5 ROWS ONLY;

    EXIT;
EOF

# -----------------------------------------------
# CHECK 5: Grid Services
# -----------------------------------------------
log_message ""
log_message "=== Oracle Restart Services ==="
$GRID_HOME/bin/crsctl status resource -t | tee -a $LOG_FILE

# -----------------------------------------------
# CHECK 6: ASM Status
# -----------------------------------------------
log_message ""
log_message "=== ASM Disk Groups ==="
su - grid -c "
    sqlplus -s / as sysasm << EOF
        SET PAGESIZE 50 LINESIZE 120
        SELECT NAME, STATE, TYPE, TOTAL_MB, FREE_MB
        FROM V\\\$ASM_DISKGROUP;
        EXIT;
EOF
" | tee -a $LOG_FILE

# -----------------------------------------------
# CHECK 7: Listener Status
# -----------------------------------------------
log_message ""
log_message "=== Listener Status ==="
lsnrctl status | tee -a $LOG_FILE

# -----------------------------------------------
# SUMMARY
# -----------------------------------------------
log_message ""
log_message "============================================"
log_message "PATCH VERIFICATION SUMMARY"
log_message "============================================"
log_message "PASSED: $PASS"
log_message "FAILED: $FAIL"
log_message "Log: $LOG_FILE"

if [ "$FAIL" -eq 0 ]; then
    log_message "✅ ALL CHECKS PASSED - Patching Successful!"
else
    log_message "❌ $FAIL CHECKS FAILED - Review and fix"
fi
log_message "============================================"
