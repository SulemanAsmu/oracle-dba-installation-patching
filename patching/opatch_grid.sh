#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Apply Release Update (RU) patch
#              to Grid Infrastructure Home
# Run As:      root user
# =============================================

GRID_HOME=/u01/app/19c/grid
GRID_USER=grid
PATCH_DIR="/tmp/patches"
PATCH_NUMBER="35643107"     # 19.21 RU
LOG_FILE="/tmp/patch_grid_$(date +%Y%m%d_%H%M%S).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Applying Patch to Grid Infrastructure"
log_message "Patch: $PATCH_NUMBER"
log_message "Grid Home: $GRID_HOME"
log_message "============================================"

# -----------------------------------------------
# STEP 1: Stop Oracle Restart / CRS Services
# -----------------------------------------------
log_message "Stopping Oracle Restart Services..."

$GRID_HOME/bin/crsctl stop has -f
sleep 10

# Verify stopped
$GRID_HOME/bin/crsctl status has 2>&1 | tee -a $LOG_FILE

log_message "✅ Grid services stopped"

# -----------------------------------------------
# STEP 2: Apply Patch to Grid Home
# -----------------------------------------------
log_message ""
log_message "Applying patch to Grid Home..."

# Run as grid user
su - $GRID_USER -c "
    $GRID_HOME/OPatch/opatch apply \
        $PATCH_DIR/$PATCH_NUMBER \
        -oh $GRID_HOME \
        -silent \
        -ocmrf /tmp/ocm.rsp \
        2>&1
" | tee -a $LOG_FILE

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    log_message "✅ Grid patch applied successfully"
else
    log_message "❌ Grid patch application FAILED"
    log_message "Starting services back..."
    $GRID_HOME/bin/crsctl start has
    exit 1
fi

# -----------------------------------------------
# STEP 3: Run root.sh for Grid (if required by patch)
# -----------------------------------------------
log_message ""
log_message "Checking if root.sh needs to run..."

if [ -f "$GRID_HOME/root.sh" ]; then
    log_message "Running Grid root.sh..."
    $GRID_HOME/root.sh | tee -a $LOG_FILE
fi

# -----------------------------------------------
# STEP 4: Start Grid Services
# -----------------------------------------------
log_message ""
log_message "Starting Oracle Restart Services..."

$GRID_HOME/bin/crsctl start has
sleep 30

# -----------------------------------------------
# STEP 5: Verify Services and Patch
# -----------------------------------------------
log_message ""
log_message "Grid Services Status:"
$GRID_HOME/bin/crsctl status resource -t | tee -a $LOG_FILE

log_message ""
log_message "Applied Patches in Grid Home:"
su - $GRID_USER -c "$GRID_HOME/OPatch/opatch lspatches" | tee -a $LOG_FILE

log_message "============================================"
log_message "✅ Grid Patching Complete"
log_message "NEXT STEP: Apply patch to Oracle DB Home"
log_message "See: 03_opatch_oracle.sh"
log_message "============================================"
