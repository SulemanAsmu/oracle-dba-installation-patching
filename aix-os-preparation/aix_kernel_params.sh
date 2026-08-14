#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Configure AIX Kernel Parameters
#              and System Settings for Oracle 19c
# Run As:      ROOT
# =============================================

LOG_FILE="/tmp/aix_kernel_config_$(date +%Y%m%d).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "AIX Kernel Parameters Configuration"
log_message "============================================"

# -----------------------------------------------
# STEP 1: Configure IPC Parameters
#         Shared Memory and Semaphores
# -----------------------------------------------
log_message "Configuring IPC Parameters..."

# Shared Memory
# SHMMAX: Maximum shared memory segment size
# Set to 90% of RAM or at least 4GB
TOTAL_RAM=$(lsattr -El sys0 -a realmem | awk '{print $2}')
SHMMAX=$((TOTAL_RAM * 1024 * 90 / 100))

chdev -l sys0 -a maxuproc=256           # Max processes per user
log_message "✅ maxuproc set to 256"

# -----------------------------------------------
# STEP 2: Configure Paging Space
# -----------------------------------------------
log_message ""
log_message "Current Paging Space:"
lsps -a | tee -a $LOG_FILE

# Add paging space if needed
# mklv -y pagelv01 -t paging datavg 16G
# mkps -s 16G -a -n /dev/pagelv01

# -----------------------------------------------
# STEP 3: Configure Shell Limits
#         in /etc/security/limits
# -----------------------------------------------
log_message ""
log_message "Configuring Shell Limits for oracle and grid users..."

# Backup original file
cp /etc/security/limits /etc/security/limits.bak_$(date +%Y%m%d)

# Set limits for oracle user
cat >> /etc/security/limits << 'EOF'

oracle:
        fsize         = -1
        core          = 2097151
        cpu           = -1
        data          = -1
        rss           = -1
        stack         = -1
        nofiles       = 65536
        threads       = 256

grid:
        fsize         = -1
        core          = 2097151
        cpu           = -1
        data          = -1
        rss           = -1
        stack         = -1
        nofiles       = 65536
        threads       = 256
EOF

log_message "✅ Shell limits configured"

# -----------------------------------------------
# STEP 4: Configure /etc/profile additions
# -----------------------------------------------
log_message "Configuring system profile..."

cat >> /etc/profile << 'EOF'

# Oracle DBA Settings
if [ $USER = "oracle" ] || [ $USER = "grid" ]; then
    ulimit -n 65536     # Open files
    ulimit -u 256       # Max user processes
    ulimit -s unlimited # Stack size
    ulimit -d unlimited # Data segment
    ulimit -f unlimited # File size
fi
EOF

log_message "✅ System profile configured"

# -----------------------------------------------
# STEP 5: Configure Large Pages (AIO)
#         AIX uses AIO for Oracle performance
# -----------------------------------------------
log_message ""
log_message "Configuring Asynchronous I/O (AIO)..."

# Enable AIO
chdev -l aio0 -a autoconfig=available
log_message "✅ AIO enabled"

# Configure large pages
vmo -p -o lgpg_regions=10 \
       -o lgpg_size=16777216
log_message "✅ Large pages configured"

# -----------------------------------------------
# STEP 6: Network Buffer Sizes
# -----------------------------------------------
log_message ""
log_message "Configuring Network Parameters..."

no -p -o tcp_sendspace=65536
no -p -o tcp_recvspace=65536
no -p -o udp_sendspace=65536
no -p -o udp_recvspace=65536
no -p -o rfc1323=1
log_message "✅ Network parameters configured"

# -----------------------------------------------
# STEP 7: Verify Settings
# -----------------------------------------------
log_message ""
log_message "--- Verification ---"
log_message "AIO Status:"
lsattr -El aio0 | tee -a $LOG_FILE

log_message ""
log_message "VMO Large Pages:"
vmo -o lgpg_regions
vmo -o lgpg_size

log_message ""
log_message "============================================"
log_message "✅ AIX Kernel Parameters Configuration Done"
log_message "⚠️  Reboot required for some settings"
log_message "============================================"
