#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Oracle Patch Pre-Check Script
#              Run BEFORE applying any patch
# Run As:      oracle user (for DB)
#              grid user (for GI)
# =============================================

GRID_HOME=/u01/app/19c/grid
ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
PATCH_DIR="/tmp/patches"
PATCH_NUMBER="35643107"     # Example: 19.21 RU patch number
LOG_FILE="/tmp/patch_precheck_$(date +%Y%m%d).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Oracle Patch Pre-Check"
log_message "Patch Number: $PATCH_NUMBER"
log_message "============================================"

# -----------------------------------------------
# CHECK 1: Current Patch Level
# -----------------------------------------------
log_message "Current Grid Infrastructure Patch Level:"
$GRID_HOME/OPatch/opatch lspatches | tee -a $LOG_FILE

log_message ""
log_message "Current Oracle DB Patch Level:"
$ORACLE_HOME/OPatch/opatch lspatches | tee -a $LOG_FILE

# -----------------------------------------------
# CHECK 2: OPatch Version
# -----------------------------------------------
log_message ""
log_message "OPatch Versions:"
log_message "Grid OPatch:"
$GRID_HOME/OPatch/opatch version | tee -a $LOG_FILE

log_message "Oracle OPatch:"
$ORACLE_HOME/OPatch/opatch version | tee -a $LOG_FILE

# -----------------------------------------------
# CHECK 3: Patch Files Available
# -----------------------------------------------
log_message ""
log_message "Checking Patch Files..."

if [ -d "$PATCH_DIR/$PATCH_NUMBER" ]; then
    log_message "✅ Patch directory found: $PATCH_DIR/$PATCH_NUMBER"
    ls -la $PATCH_DIR/$PATCH_NUMBER | tee -a $LOG_FILE
else
    log_message "❌ Patch directory NOT found: $PATCH_DIR/$PATCH_NUMBER"
    log_message "   Extract patch zip first:"
    log_message "   unzip p${PATCH_NUMBER}_190000_AIX64-5L.zip -d $PATCH_DIR"
    exit 1
fi

# -----------------------------------------------
# CHECK 4: Disk Space Check
# -----------------------------------------------
log_message ""
log_message "Disk Space Check:"

GRID_FREE=$(df -m $GRID_HOME | awk 'NR==2{print $3}')
ORACLE_FREE=$(df -m $ORACLE_HOME | awk 'NR==2{print $3}')
TMP_FREE=$(df -m /tmp | awk 'NR==2{print $3}')

log_message "Grid Home free:   ${GRID_FREE}MB (need 5GB)"
log_message "Oracle Home free: ${ORACLE_FREE}MB (need 5GB)"
log_message "/tmp free:        ${TMP_FREE}MB (need 2GB)"

[ "$GRID_FREE"   -lt 5120 ] && log_message "❌ Not enough space in Grid Home"
[ "$ORACLE_FREE" -lt 5120 ] && log_message "❌ Not enough space in Oracle Home"
[ "$TMP_FREE"    -lt 2048 ] && log_message "❌ Not enough space in /tmp"

# -----------------------------------------------
# CHECK 5: Run OPatch Conflict Check
# -----------------------------------------------
log_message ""
log_message "Running OPatch Conflict Check for Grid..."

$GRID_HOME/OPatch/opatch prereq \
    CheckConflictAgainstOHWithDetail \
    -ph $PATCH_DIR/$PATCH_NUMBER \
    2>&1 | tee -a $LOG_FILE

log_message ""
log_message "Running OPatch Conflict Check for Oracle..."

$ORACLE_HOME/OPatch/opatch prereq \
    CheckConflictAgainstOHWithDetail \
    -ph $PATCH_DIR/$PATCH_NUMBER \
    2>&1 | tee -a $LOG_FILE

# -----------------------------------------------
# CHECK 6: Database Status
# -----------------------------------------------
log_message ""
log_message "Database Status:"

sqlplus -s / as sysdba << EOF | tee -a $LOG_FILE
    SET PAGESIZE 0 FEEDBACK OFF
    SELECT 'DB Name: ' || NAME FROM V\$DATABASE;
    SELECT 'Version: ' || VERSION FROM V\$INSTANCE;
    SELECT 'Status:  ' || STATUS  FROM V\$INSTANCE;
    SELECT 'Open Mode: ' || OPEN_MODE FROM V\$DATABASE;
    EXIT;
EOF

# -----------------------------------------------
# CHECK 7: Active Sessions
# -----------------------------------------------
log_message ""
log_message "Active User Sessions (will be disconnected):"

sqlplus -s / as sysdba << EOF | tee -a $LOG_FILE
    SELECT
        COUNT(*) AS ACTIVE_SESSIONS
    FROM V\$SESSION
    WHERE STATUS = 'ACTIVE'
      AND USERNAME IS NOT NULL;
    EXIT;
EOF

log_message ""
log_message "============================================"
log_message "⚠️  PRE-PATCH CHECKLIST:"
log_message "  [ ] Take RMAN full backup"
log_message "  [ ] Notify application teams"
log_message "  [ ] Plan maintenance window"
log_message "  [ ] Read patch README.html"
log_message "  [ ] All checks above PASSED"
log_message "============================================"
