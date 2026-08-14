#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Grid Infrastructure Pre-Install
#              Checks before GI installation
# Run As:      ROOT
# =============================================

LOG_FILE="/tmp/grid_preinstall_$(date +%Y%m%d).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Grid Infrastructure Pre-Install Check"
log_message "============================================"

# -----------------------------------------------
# CHECK 1: Grid Home Directory
# -----------------------------------------------
GRID_HOME="/u01/app/19c/grid"

if [ -d "$GRID_HOME" ]; then
    log_message "✅ Grid Home exists: $GRID_HOME"
    SPACE=$(df -m $GRID_HOME | awk 'NR==2{print $3}')
    log_message "   Free Space: ${SPACE}MB"
    if [ "$SPACE" -lt 12288 ]; then
        log_message "❌ Not enough space in Grid Home (need 12GB)"
        exit 1
    fi
else
    log_message "❌ Grid Home not found: $GRID_HOME"
    exit 1
fi

# -----------------------------------------------
# CHECK 2: Grid Software Zip File
# -----------------------------------------------
GRID_ZIP="/tmp/LINUX.X64_193000_grid_home.zip"
# For AIX it will be AIX specific zip
GRID_ZIP_AIX="/tmp/AIX.PPC64_193000_grid_home.zip"

if [ -f "$GRID_ZIP_AIX" ]; then
    log_message "✅ Grid software zip found: $GRID_ZIP_AIX"
    SIZE=$(du -m $GRID_ZIP_AIX | cut -f1)
    log_message "   File Size: ${SIZE}MB"
else
    log_message "❌ Grid software zip NOT found: $GRID_ZIP_AIX"
    log_message "   Download from Oracle Support (MOS)"
    exit 1
fi

# -----------------------------------------------
# CHECK 3: OPatch Version for Grid
# -----------------------------------------------
OPATCH_ZIP="/tmp/p6880880_190000_AIX64-5L.zip"

if [ -f "$OPATCH_ZIP" ]; then
    log_message "✅ OPatch zip found: $OPATCH_ZIP"
else
    log_message "⚠️  OPatch zip not found - download latest OPatch"
fi

# -----------------------------------------------
# CHECK 4: ASM Disks Available
# -----------------------------------------------
log_message ""
log_message "Checking ASM Disks..."

for DISK in hdisk2 hdisk3 hdisk4; do
    if lsdev -l $DISK > /dev/null 2>&1; then
        DISK_SIZE=$(lsattr -El $DISK -a size_in_mb \
                    2>/dev/null | awk '{print $2}')
        log_message "✅ ASM Disk available: $DISK"
    else
        log_message "❌ ASM Disk NOT found: $DISK"
    fi
done

# -----------------------------------------------
# CHECK 5: grid User Environment
# -----------------------------------------------
log_message ""
log_message "Checking grid user environment..."

su - grid -c "echo \$ORACLE_HOME" | tee -a $LOG_FILE
su - grid -c "echo \$ORACLE_BASE" | tee -a $LOG_FILE
su - grid -c "id" | tee -a $LOG_FILE

# -----------------------------------------------
# CHECK 6: Extract Grid Software
# -----------------------------------------------
log_message ""
log_message "Ready to Extract Grid Software to $GRID_HOME"
log_message "Run as grid user:"
log_message "  cd $GRID_HOME"
log_message "  unzip -q /tmp/AIX.PPC64_193000_grid_home.zip"
log_message ""
log_message "============================================"
log_message "✅ Pre-Install Check Complete"
log_message "============================================"
