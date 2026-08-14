#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: AIX Pre-Installation Requirements
#              Check for Oracle 19c
#              Run as ROOT before installation
# =============================================

LOG_FILE="/tmp/aix_prereq_check_$(date +%Y%m%d).log"
PASS=0
FAIL=0
WARN=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_and_print() {
    echo "$1" | tee -a $LOG_FILE
}

check_pass() {
    echo -e "${GREEN}[PASS]${NC} $1" | tee -a $LOG_FILE
    ((PASS++))
}

check_fail() {
    echo -e "${RED}[FAIL]${NC} $1" | tee -a $LOG_FILE
    ((FAIL++))
}

check_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a $LOG_FILE
    ((WARN++))
}

log_and_print "============================================"
log_and_print "Oracle 19c AIX Pre-Installation Check"
log_and_print "Date: $(date)"
log_and_print "============================================"

# -----------------------------------------------
# CHECK 1: AIX Version
# -----------------------------------------------
log_and_print ""
log_and_print "--- AIX OS Version ---"
AIX_VERSION=$(oslevel -r)
log_and_print "AIX Level: $AIX_VERSION"

# Oracle 19c requires AIX 7.1 TL4 or higher
AIX_MAJOR=$(oslevel | cut -d'.' -f1)
AIX_MINOR=$(oslevel | cut -d'.' -f2)

if [ "$AIX_MAJOR" -ge 7 ] && [ "$AIX_MINOR" -ge 1 ]; then
    check_pass "AIX Version $AIX_VERSION is supported"
else
    check_fail "AIX Version $AIX_VERSION is NOT supported for Oracle 19c"
fi

# -----------------------------------------------
# CHECK 2: Hardware - CPU and Memory
# -----------------------------------------------
log_and_print ""
log_and_print "--- Hardware Requirements ---"

# Check RAM (minimum 1GB for Oracle, recommended 8GB+)
RAM_MB=$(lsattr -El sys0 -a realmem | awk '{print $2/1024}')
RAM_GB=$(echo "$RAM_MB / 1024" | bc)
log_and_print "RAM: ${RAM_GB}GB"

if [ "$RAM_GB" -ge 8 ]; then
    check_pass "RAM: ${RAM_GB}GB meets Oracle 19c requirement (min 8GB)"
elif [ "$RAM_GB" -ge 1 ]; then
    check_warn "RAM: ${RAM_GB}GB meets minimum but 8GB+ recommended"
else
    check_fail "RAM: ${RAM_GB}GB is below Oracle 19c minimum (1GB)"
fi

# Check CPU
CPU_COUNT=$(lsdev -Cc processor | wc -l | tr -d ' ')
log_and_print "CPU Count: $CPU_COUNT"
check_pass "CPU Count: $CPU_COUNT"

# -----------------------------------------------
# CHECK 3: Swap Space
# -----------------------------------------------
log_and_print ""
log_and_print "--- Swap Space ---"

SWAP_MB=$(lsps -s | awk 'NR==2{print $1}' | sed 's/MB//')
SWAP_GB=$(echo "$SWAP_MB / 1024" | bc)
log_and_print "Swap Space: ${SWAP_GB}GB"

if [ "$SWAP_GB" -ge 16 ]; then
    check_pass "Swap: ${SWAP_GB}GB meets requirement"
elif [ "$SWAP_GB" -ge 2 ]; then
    check_warn "Swap: ${SWAP_GB}GB is low, recommended 16GB for production"
else
    check_fail "Swap: ${SWAP_GB}GB is below minimum requirement"
fi

# -----------------------------------------------
# CHECK 4: Disk Space Requirements
# -----------------------------------------------
log_and_print ""
log_and_print "--- Disk Space Requirements ---"

# Check /tmp (minimum 1GB)
TMP_FREE=$(df -m /tmp | awk 'NR==2{print $3}')
if [ "$TMP_FREE" -ge 1024 ]; then
    check_pass "/tmp free space: ${TMP_FREE}MB (min 1GB)"
else
    check_fail "/tmp free space: ${TMP_FREE}MB - needs at least 1GB"
fi

# Check /u01 for Oracle Software (minimum 15GB)
if df -m /u01 > /dev/null 2>&1; then
    U01_FREE=$(df -m /u01 | awk 'NR==2{print $3}')
    if [ "$U01_FREE" -ge 15360 ]; then
        check_pass "/u01 free space: ${U01_FREE}MB (min 15GB)"
    else
        check_fail "/u01 free space: ${U01_FREE}MB needs at least 15GB"
    fi
else
    check_fail "/u01 filesystem does not exist - must be created"
fi

# Check /u01/app/oracle/19c (Oracle Home - 10GB)
log_and_print "Oracle Home needs minimum 10GB free"

# -----------------------------------------------
# CHECK 5: Required AIX Filesets (Packages)
# -----------------------------------------------
log_and_print ""
log_and_print "--- Required AIX Filesets ---"

# List of required filesets for Oracle 19c on AIX
REQUIRED_FILESETS=(
    "bos.adt.base"
    "bos.adt.lib"
    "bos.adt.libm"
    "bos.perf.libperfstat"
    "bos.perf.perfstat"
    "bos.perf.proctools"
    "xlC.aix61.rte"
    "xlC.rte"
    "rsct.basic.rte"
    "rsct.compat.clients.rte"
)

for fileset in "${REQUIRED_FILESETS[@]}"; do
    if lslpp -l $fileset > /dev/null 2>&1; then
        VERSION=$(lslpp -l $fileset | awk 'NR==3{print $2}')
        check_pass "Fileset installed: $fileset ($VERSION)"
    else
        check_fail "Fileset MISSING: $fileset - must be installed"
    fi
done

# -----------------------------------------------
# CHECK 6: Groups and Users
# -----------------------------------------------
log_and_print ""
log_and_print "--- Required OS Users and Groups ---"

# Check groups
for GROUP in oinstall dba oper asmadmin asmdba asmoper; do
    if lsgroup $GROUP > /dev/null 2>&1; then
        check_pass "Group exists: $GROUP"
    else
        check_fail "Group MISSING: $GROUP"
    fi
done

# Check users
for USER in oracle grid; do
    if lsuser $USER > /dev/null 2>&1; then
        check_pass "User exists: $USER"
    else
        check_fail "User MISSING: $USER"
    fi
done

# -----------------------------------------------
# CHECK 7: Network Configuration
# -----------------------------------------------
log_and_print ""
log_and_print "--- Network Configuration ---"

HOSTNAME=$(hostname)
log_and_print "Hostname: $HOSTNAME"

# Check hostname resolves
if nslookup $HOSTNAME > /dev/null 2>&1; then
    check_pass "Hostname $HOSTNAME resolves correctly"
else
    check_warn "Hostname $HOSTNAME DNS resolution issue"
fi

# Check /etc/hosts entry
if grep -q "$HOSTNAME" /etc/hosts; then
    check_pass "Hostname found in /etc/hosts"
else
    check_warn "Hostname not in /etc/hosts - add it"
fi

# -----------------------------------------------
# CHECK 8: Shell Limits (ulimits)
# -----------------------------------------------
log_and_print ""
log_and_print "--- Shell Limits for oracle user ---"

# These should be set for oracle user
log_and_print "Current ulimits for oracle user:"
su - oracle -c "ulimit -a" 2>/dev/null | tee -a $LOG_FILE

# -----------------------------------------------
# SUMMARY
# -----------------------------------------------
log_and_print ""
log_and_print "============================================"
log_and_print "PRE-INSTALLATION CHECK SUMMARY"
log_and_print "============================================"
log_and_print "PASSED:   $PASS"
log_and_print "FAILED:   $FAIL"
log_and_print "WARNINGS: $WARN"
log_and_print "============================================"
log_and_print "Log saved to: $LOG_FILE"

if [ "$FAIL" -gt 0 ]; then
    log_and_print "❌ FAILED: Fix all FAIL items before installation"
    exit 1
else
    log_and_print "✅ PASSED: System is ready for Oracle installation"
    exit 0
fi
