#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Create Oracle Filesystems on AIX
#              Volume Groups and Logical Volumes
# Run As:      ROOT
# =============================================

LOG_FILE="/tmp/aix_filesystem_$(date +%Y%m%d).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Oracle Filesystem Setup on AIX"
log_message "============================================"

# -----------------------------------------------
# VARIABLES - Adjust for your environment
# -----------------------------------------------
# Disk for Oracle software volume group
ORACLE_DISK="hdisk1"

# Disk for ASM (raw disks for ASM disk groups)
ASM_DISK1="hdisk2"
ASM_DISK2="hdisk3"
ASM_DISK3="hdisk4"

# Volume group name for Oracle software
VG_NAME="oraclevg"

# -----------------------------------------------
# STEP 1: Create Volume Group for Oracle Software
# -----------------------------------------------
log_message "Creating Volume Group: $VG_NAME..."

# Check disk is available
lsdev -l $ORACLE_DISK | tee -a $LOG_FILE

# Create Volume Group
mkvg -y $VG_NAME \
     -s 32 \
     $ORACLE_DISK

log_message "✅ Volume Group created: $VG_NAME"

# -----------------------------------------------
# STEP 2: Create Logical Volumes
# -----------------------------------------------
log_message ""
log_message "Creating Logical Volumes..."

# Oracle Base LV - 5GB
mklv -y orabase_lv \
     -t jfs2 \
     -s y \
     $VG_NAME 5G
log_message "✅ LV created: orabase_lv (5GB)"

# Oracle Home LV - 15GB (Oracle software)
mklv -y orahome_lv \
     -t jfs2 \
     -s y \
     $VG_NAME 15G
log_message "✅ LV created: orahome_lv (15GB)"

# Grid Home LV - 15GB (Grid software)
mklv -y gridhome_lv \
     -t jfs2 \
     -s y \
     $VG_NAME 15G
log_message "✅ LV created: gridhome_lv (15GB)"

# FRA LV - 50GB (Fast Recovery Area)
mklv -y fra_lv \
     -t jfs2 \
     -s y \
     $VG_NAME 50G
log_message "✅ LV created: fra_lv (50GB)"

# -----------------------------------------------
# STEP 3: Create Filesystems
# -----------------------------------------------
log_message ""
log_message "Creating Filesystems..."

# Create JFS2 filesystems
crfs -v jfs2 -d orabase_lv  -m /u01/app/oracle     -A yes -p rw
crfs -v jfs2 -d orahome_lv  -m /u01/app/oracle/product/19c/dbhome_1 -A yes -p rw
crfs -v jfs2 -d gridhome_lv -m /u01/app/19c/grid   -A yes -p rw
crfs -v jfs2 -d fra_lv      -m /u01/fra             -A yes -p rw

log_message "✅ Filesystems created"

# -----------------------------------------------
# STEP 4: Mount Filesystems
# -----------------------------------------------
log_message ""
log_message "Mounting Filesystems..."

mount /u01/app/oracle
mount /u01/app/oracle/product/19c/dbhome_1
mount /u01/app/19c/grid
mount /u01/fra

log_message "✅ Filesystems mounted"

# -----------------------------------------------
# STEP 5: Create Directory Structure
# -----------------------------------------------
log_message ""
log_message "Creating Directory Structure..."

# Oracle directories
mkdir -p /u01/app/oracle
mkdir -p /u01/app/oracle/product/19c/dbhome_1
mkdir -p /u01/app/oracle/admin
mkdir -p /u01/app/oracle/diag
mkdir -p /u01/app/oraInventory

# Grid directories
mkdir -p /u01/app/19c/grid
mkdir -p /u01/app/grid
mkdir -p /u01/fra

log_message "✅ Directories created"

# -----------------------------------------------
# STEP 6: Set Permissions
# -----------------------------------------------
log_message ""
log_message "Setting Permissions..."

chown -R oracle:oinstall /u01/app/oracle
chown -R grid:oinstall   /u01/app/19c/grid
chown -R grid:oinstall   /u01/app/grid
chown -R oracle:oinstall /u01/fra
chown    root:oinstall   /u01/app
chown    grid:oinstall   /u01/app/oraInventory

chmod -R 775 /u01/app/oracle
chmod -R 775 /u01/app/19c/grid
chmod -R 777 /u01/fra
chmod    755 /u01/app

log_message "✅ Permissions set"

# -----------------------------------------------
# STEP 7: Prepare ASM Disks
#         Change ownership to grid user
# -----------------------------------------------
log_message ""
log_message "Preparing ASM Disks..."

# Change disk ownership to grid user
for DISK in $ASM_DISK1 $ASM_DISK2 $ASM_DISK3; do
    chown grid:asmadmin /dev/r${DISK}
    chmod 660 /dev/r${DISK}
    log_message "✅ ASM Disk prepared: $DISK"
done

# Verify ASM disk permissions
log_message ""
log_message "ASM Disk Permissions:"
ls -la /dev/r${ASM_DISK1} \
       /dev/r${ASM_DISK2} \
       /dev/r${ASM_DISK3} | tee -a $LOG_FILE

# -----------------------------------------------
# STEP 8: Verify All Filesystems
# -----------------------------------------------
log_message ""
log_message "--- Filesystem Verification ---"
df -g /u01/app/oracle \
      /u01/app/19c/grid \
      /u01/fra | tee -a $LOG_FILE

log_message "============================================"
log_message "✅ AIX Filesystem Setup Complete"
log_message "============================================"
