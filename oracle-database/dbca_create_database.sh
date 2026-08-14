#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Create Oracle Database using DBCA
#              Silent Mode with ASM Storage
# Run As:      oracle user
# =============================================

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export ORACLE_SID=COMPANYDB
export PATH=$ORACLE_HOME/bin:$PATH

LOG_FILE="/tmp/dbca_create_$(date +%Y%m%d_%H%M%S).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Creating Oracle Database: $ORACLE_SID"
log_message "Storage: Oracle ASM"
log_message "============================================"

# -----------------------------------------------
# Create Database using DBCA Silent Mode
# -----------------------------------------------
$ORACLE_HOME/bin/dbca \
    -silent \
    -createDatabase \
    -templateName General_Purpose.dbc \
    -gdbName COMPANYDB \
    -sid COMPANYDB \
    -databaseConfigType SINGLE \
    -createAsContainerDatabase false \
    -characterSet AL32UTF8 \
    -nationalCharacterSet AL16UTF16 \
    -sysPassword SysPass123! \
    -systemPassword SysPass123! \
    -dbsnmpPassword DbsnmpPass123! \
    -storageType ASM \
    -diskGroupName DATA \
    -recoveryAreaDestination +FRA \
    -recoveryAreaSize 51200 \
    -redoLogFileSize 200 \
    -initParams \
        "db_name=COMPANYDB,\
         db_unique_name=COMPANYDB,\
         db_block_size=8192,\
         sga_target=2G,\
         pga_aggregate_target=512M,\
         processes=300,\
         open_cursors=300,\
         undo_tablespace=UNDOTBS1,\
         control_files='+DATA/COMPANYDB/control01.ctl\,+FRA/COMPANYDB/control02.ctl',\
         log_archive_dest_1='LOCATION=USE_DB_RECOVERY_FILE_DEST',\
         enable_pluggable_database=false,\
         audit_trail=DB,\
         nls_date_format=DD-MON-YYYY HH24:MI:SS" \
    -automaticMemoryManagement false \
    -totalMemory 0 \
    -emConfiguration NONE \
    2>&1 | tee -a $LOG_FILE

if [ $? -eq 0 ]; then
    log_message "✅ Database $ORACLE_SID created successfully"
else
    log_message "❌ Database creation failed - check $LOG_FILE"
    exit 1
fi

# -----------------------------------------------
# Register Database with Oracle Restart
# -----------------------------------------------
log_message ""
log_message "Registering database with Oracle Restart..."

srvctl add database \
    -db COMPANYDB \
    -oraclehome $ORACLE_HOME \
    -dbtype SINGLE \
    -diskgroup "DATA,FRA" \
    -instance COMPANYDB \
    -role PRIMARY \
    -startoption OPEN \
    -stopoption IMMEDIATE

srvctl start database -db COMPANYDB

srvctl status database -db COMPANYDB | tee -a $LOG_FILE

log_message "============================================"
log_message "✅ Database Creation Complete"
log_message "NEXT STEP: Post Installation Tasks"
log_message "============================================"
