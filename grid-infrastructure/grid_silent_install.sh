#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Oracle Grid Infrastructure 19c
#              Silent Installation on AIX
# Run As:      grid user
# =============================================

export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19c/grid
export PATH=$ORACLE_HOME/bin:$PATH

LOG_FILE="/tmp/grid_install_$(date +%Y%m%d_%H%M%S).log"
RESPONSE_FILE="/tmp/grid_install.rsp"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Oracle Grid Infrastructure 19c Installation"
log_message "AIX OS"
log_message "============================================"

# -----------------------------------------------
# STEP 1: Extract Grid Software
# -----------------------------------------------
log_message "Extracting Grid Software..."

cd $ORACLE_HOME
unzip -q /tmp/AIX.PPC64_193000_grid_home.zip

log_message "✅ Grid software extracted"

# -----------------------------------------------
# STEP 2: Update OPatch to Latest Version
# -----------------------------------------------
log_message "Updating OPatch..."

# Backup old OPatch
mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_bak_$(date +%Y%m%d)

# Extract new OPatch
cd $ORACLE_HOME
unzip -q /tmp/p6880880_190000_AIX64-5L.zip

log_message "✅ OPatch updated"
$ORACLE_HOME/OPatch/opatch version | tee -a $LOG_FILE

# -----------------------------------------------
# STEP 3: Create Response File
# -----------------------------------------------
log_message ""
log_message "Creating Grid Install Response File..."

cat > $RESPONSE_FILE << 'EOF'
###############################################
# Oracle Grid Infrastructure 19c
# Silent Install Response File for AIX
# Single Instance with ASM
###############################################

oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v19.0.0

#-----------------------------------------------
# Installation Option
# CRS_CONFIG    = New Grid Infrastructure install
# HA_CONFIG     = Oracle Restart (single instance)
# UPGRADE       = Upgrade existing GI
#-----------------------------------------------
oracle.install.option=HA_CONFIG

# ORACLE_BASE for Grid Infrastructure
ORACLE_BASE=/u01/app/grid

# Grid Home Location
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin

#-----------------------------------------------
# ASM Configuration
#-----------------------------------------------
oracle.install.asm.storageOption=ASM

# ASM Disk Group for DATA
oracle.install.asm.diskGroup.name=DATA
oracle.install.asm.diskGroup.redundancy=EXTERNAL
oracle.install.asm.diskGroup.AUSize=4

# ASM Disks (raw devices on AIX)
# Format: /dev/rdiskX for AIX
oracle.install.asm.diskGroup.disksWithFailureGroupNames=/dev/rhdisk2,,/dev/rhdisk3,
oracle.install.asm.diskGroup.disks=/dev/rhdisk2,/dev/rhdisk3

# ASM Password
oracle.install.asm.monitorPassword=AsmMonitor123!

# Inventory Location
INVENTORY_LOCATION=/u01/app/oraInventory
SELECTED_LANGUAGES=en

EOF

log_message "✅ Response file created: $RESPONSE_FILE"

# -----------------------------------------------
# STEP 4: Run Grid Installation (Silent Mode)
# -----------------------------------------------
log_message ""
log_message "Starting Grid Infrastructure Silent Installation..."
log_message "This may take 30-60 minutes..."

$ORACLE_HOME/gridSetup.sh \
    -silent \
    -responseFile $RESPONSE_FILE \
    -ignorePrereqFailure \
    >> $LOG_FILE 2>&1

INSTALL_RC=$?

if [ $INSTALL_RC -eq 0 ]; then
    log_message "✅ Grid Installation Completed Successfully"
else
    log_message "⚠️  Grid Installation completed with warnings (RC=$INSTALL_RC)"
    log_message "    Check log: $LOG_FILE"
fi

log_message ""
log_message "============================================"
log_message "NEXT STEP: Run root scripts as ROOT user"
log_message "See: 03_grid_root_scripts.sh"
log_message "============================================"
