#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Grid Infrastructure Configuration
#              ASM Disk Groups Setup
# Run As:      grid user
# =============================================

export ORACLE_HOME=/u01/app/19c/grid
export ORACLE_SID=+ASM
export PATH=$ORACLE_HOME/bin:$PATH

LOG_FILE="/tmp/grid_config_$(date +%Y%m%d).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Grid Infrastructure Configuration"
log_message "ASM Disk Groups Setup"
log_message "============================================"

# -----------------------------------------------
# STEP 1: Create FRA Disk Group
# -----------------------------------------------
log_message "Creating FRA Disk Group..."

sqlplus -s / as sysasm << EOF | tee -a $LOG_FILE

-- Create FRA (Fast Recovery Area) Disk Group
CREATE DISKGROUP FRA
    EXTERNAL REDUNDANCY
    DISK '/dev/rhdisk4'
    ATTRIBUTE
        'compatible.asm'    = '19.0.0.0.0',
        'compatible.rdbms'  = '19.0.0.0.0',
        'au_size'           = '4M';

-- Check disk groups created
SELECT
    NAME,
    STATE,
    TYPE,
    TOTAL_MB,
    FREE_MB,
    ROUND((TOTAL_MB-FREE_MB)/TOTAL_MB*100,2) AS PCT_USED
FROM V\$ASM_DISKGROUP
ORDER BY NAME;

EXIT;
EOF

log_message "✅ FRA Disk Group created"

# -----------------------------------------------
# STEP 2: Check All ASM Disk Groups
# -----------------------------------------------
log_message ""
log_message "All ASM Disk Groups:"

sqlplus -s / as sysasm << EOF | tee -a $LOG_FILE

-- Show all disk groups with detail
SELECT
    dg.NAME                             AS DISK_GROUP,
    dg.STATE,
    dg.TYPE                             AS REDUNDANCY,
    dg.TOTAL_MB / 1024                  AS TOTAL_GB,
    dg.FREE_MB / 1024                   AS FREE_GB,
    dg.USABLE_FILE_MB / 1024            AS USABLE_GB,
    COUNT(d.DISK_NUMBER)                AS NUM_DISKS
FROM V\$ASM_DISKGROUP dg
JOIN V\$ASM_DISK d
    ON dg.GROUP_NUMBER = d.GROUP_NUMBER
GROUP BY
    dg.NAME, dg.STATE, dg.TYPE,
    dg.TOTAL_MB, dg.FREE_MB,
    dg.USABLE_FILE_MB
ORDER BY dg.NAME;

-- Show disk details
SELECT
    dg.NAME                  AS DISK_GROUP,
    d.DISK_NUMBER,
    d.NAME                   AS DISK_NAME,
    d.PATH                   AS DISK_PATH,
    d.TOTAL_MB,
    d.FREE_MB,
    d.STATE,
    d.MODE_STATUS
FROM V\$ASM_DISKGROUP dg
JOIN V\$ASM_DISK d
    ON dg.GROUP_NUMBER = d.GROUP_NUMBER
ORDER BY dg.NAME, d.DISK_NUMBER;

EXIT;
EOF

# -----------------------------------------------
# STEP 3: Verify Oracle Restart Services
# -----------------------------------------------
log_message ""
log_message "Oracle Restart Services Status:"

$ORACLE_HOME/bin/crsctl status resource -t | tee -a $LOG_FILE

log_message ""
log_message "OHAS Status:"
$ORACLE_HOME/bin/crsctl check has | tee -a $LOG_FILE

log_message "============================================"
log_message "✅ Grid Configuration Complete"
log_message "NEXT STEP: Install Oracle Database Software"
log_message "See: ../oracle-database/"
log_message "============================================"
