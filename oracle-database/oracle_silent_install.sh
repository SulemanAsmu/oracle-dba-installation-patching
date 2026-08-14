#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Oracle Database 19c
#              Silent Installation on AIX
# Run As:      oracle user
# =============================================

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export PATH=$ORACLE_HOME/bin:$PATH

LOG_FILE="/tmp/oracle_install_$(date +%Y%m%d_%H%M%S).log"
RESPONSE_FILE="/tmp/oracle_install.rsp"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Oracle Database 19c Silent Installation"
log_message "IBM AIX"
log_message "============================================"

# -----------------------------------------------
# STEP 1: Extract Oracle Software
# -----------------------------------------------
log_message "Extracting Oracle Database Software..."

cd $ORACLE_HOME
unzip -q /tmp/AIX.PPC64_193000_db_home.zip

log_message "✅ Oracle software extracted"

# -----------------------------------------------
# STEP 2: Update OPatch
# -----------------------------------------------
log_message "Updating OPatch..."

mv $ORACLE_HOME/OPatch $ORACLE_HOME/OPatch_bak_$(date +%Y%m%d)
cd $ORACLE_HOME
unzip -q /tmp/p6880880_190000_AIX64-5L.zip

$ORACLE_HOME/OPatch/opatch version | tee -a $LOG_FILE
log_message "✅ OPatch updated"

# -----------------------------------------------
# STEP 3: Create Oracle Install Response File
# -----------------------------------------------
log_message "Creating Oracle Install Response File..."

cat > $RESPONSE_FILE << 'EOF'
###############################################
# Oracle Database 19c
# Silent Install Response File - AIX
###############################################

oracle.install.responseFileVersion=/oracle/install/rspfmt_dbinstall_response_schema_v19.0.0

#-----------------------------------------------
# Installation Type
# INSTALL_DB_SWONLY  = Software Only
# INSTALL_DB_AND_CONFIG = Software + DB Creation
#-----------------------------------------------
oracle.install.option=INSTALL_DB_SWONLY

# Oracle Base and Home
ORACLE_BASE=/u01/app/oracle
ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1

# Install Edition
# EE = Enterprise Edition
# SE2 = Standard Edition 2
oracle.install.db.InstallEdition=EE

#-----------------------------------------------
# OS Groups
#-----------------------------------------------
oracle.install.db.OSDBA_GROUP=dba
oracle.install.db.OSOPER_GROUP=oper
oracle.install.db.OSBACKUPDBA_GROUP=dba
oracle.install.db.OSDGDBA_GROUP=dba
oracle.install.db.OSKMDBA_GROUP=dba
oracle.install.db.OSRACDBA_GROUP=dba

# Inventory
INVENTORY_LOCATION=/u01/app/oraInventory
SELECTED_LANGUAGES=en

# Skip updates (download separately)
oracle.installer.autoupdates.option=SKIP_UPDATES

EOF

log_message "✅ Response file created"

# -----------------------------------------------
# STEP 4: Run Oracle Software Installation
# -----------------------------------------------
log_message ""
log_message "Starting Oracle Database 19c Installation..."
log_message "This may take 30-60 minutes..."

$ORACLE_HOME/runInstaller \
    -silent \
    -responseFile $RESPONSE_FILE \
    -ignorePrereqFailure \
    -waitForCompletion \
    >> $LOG_FILE 2>&1

INSTALL_RC=$?

if [ $INSTALL_RC -eq 0 ] || [ $INSTALL_RC -eq 6 ]; then
    log_message "✅ Oracle Installation Completed (RC=$INSTALL_RC)"
else
    log_message "❌ Oracle Installation Failed (RC=$INSTALL_RC)"
    log_message "Check: $LOG_FILE"
    exit 1
fi

log_message ""
log_message "============================================"
log_message "NEXT STEP: Run root scripts as ROOT"
log_message "See: 03_oracle_root_scripts.sh"
log_message "============================================"
