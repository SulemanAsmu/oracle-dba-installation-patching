#!/bin/bash
# =============================================
# OS:          IBM AIX 7.2 / 7.3
# Author:      Suleman
# Description: Create Oracle Required
#              Users and Groups on AIX
# Run As:      ROOT
# =============================================

LOG_FILE="/tmp/aix_users_groups_$(date +%Y%m%d).log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a $LOG_FILE
}

log_message "============================================"
log_message "Creating Oracle Users and Groups on AIX"
log_message "============================================"

# -----------------------------------------------
# STEP 1: Create Required Groups
# -----------------------------------------------
log_message "Creating Oracle Groups..."

# oinstall - Oracle Inventory Group
mkgroup -A id=1001 oinstall
log_message "✅ Group created: oinstall (GID=1001)"

# dba - Database Administrator Group
mkgroup -A id=1002 dba
log_message "✅ Group created: dba (GID=1002)"

# oper - Database Operator Group
mkgroup -A id=1003 oper
log_message "✅ Group created: oper (GID=1003)"

# asmadmin - ASM Administrator Group
mkgroup -A id=1004 asmadmin
log_message "✅ Group created: asmadmin (GID=1004)"

# asmdba - ASM DBA Group
mkgroup -A id=1005 asmdba
log_message "✅ Group created: asmdba (GID=1005)"

# asmoper - ASM Operator Group
mkgroup -A id=1006 asmoper
log_message "✅ Group created: asmoper (GID=1006)"

# -----------------------------------------------
# STEP 2: Create Grid Infrastructure User
# -----------------------------------------------
log_message ""
log_message "Creating grid user..."

mkuser \
    id=1100 \
    pgrp=oinstall \
    groups=oinstall,dba,asmadmin,asmdba,asmoper \
    home=/home/grid \
    shell=/usr/bin/ksh \
    gecos="Oracle Grid Infrastructure" \
    grid

# Set password
echo "grid:Grid_Password123!" | chpasswd
log_message "✅ User created: grid"

# -----------------------------------------------
# STEP 3: Create Oracle Database User
# -----------------------------------------------
log_message "Creating oracle user..."

mkuser \
    id=1101 \
    pgrp=oinstall \
    groups=oinstall,dba,oper,asmdba \
    home=/home/oracle \
    shell=/usr/bin/ksh \
    gecos="Oracle Database Administrator" \
    oracle

# Set password
echo "oracle:Oracle_Password123!" | chpasswd
log_message "✅ User created: oracle"

# -----------------------------------------------
# STEP 4: Set Oracle User Environment (.profile)
# -----------------------------------------------
log_message ""
log_message "Configuring oracle user environment..."

cat > /home/oracle/.profile << 'EOF'
# =============================================
# Oracle User Environment Profile
# AIX - Oracle 19c
# =============================================

# Oracle Environment
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/19c/dbhome_1
export ORACLE_SID=COMPANYDB
export ORACLE_UNQNAME=COMPANYDB

# Oracle Path
export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:$PATH

# Library Path (AIX uses LIBPATH)
export LIBPATH=$ORACLE_HOME/lib:$ORACLE_HOME/lib32:/usr/lib:$LIBPATH

# TNS Admin
export TNS_ADMIN=$ORACLE_HOME/network/admin

# NLS Settings
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

# Shell Settings
export EDITOR=vi
set -o vi
stty erase ^H

# Aliases
alias dbs='sqlplus / as sysdba'
alias alert='tail -100f $ORACLE_BASE/diag/rdbms/*/*/trace/alert_$ORACLE_SID.log'
alias lsoh='$ORACLE_HOME/OPatch/opatch lspatches'
alias asmcmd='$ORACLE_HOME/bin/asmcmd'

# Function to switch database
function setdb() {
    export ORACLE_SID=$1
    export ORACLE_UNQNAME=$1
    echo "✅ ORACLE_SID set to: $ORACLE_SID"
}

PS1='[oracle@$(hostname):$ORACLE_SID] $ '

echo "Oracle Environment Loaded - SID: $ORACLE_SID"
EOF

chown oracle:oinstall /home/oracle/.profile
log_message "✅ Oracle .profile configured"

# -----------------------------------------------
# STEP 5: Set Grid User Environment (.profile)
# -----------------------------------------------
log_message "Configuring grid user environment..."

cat > /home/grid/.profile << 'EOF'
# =============================================
# Grid Infrastructure User Environment
# AIX - Oracle Grid 19c
# =============================================

# Grid Environment
export ORACLE_BASE=/u01/app/grid
export ORACLE_HOME=/u01/app/19c/grid
export ORACLE_SID=+ASM

# Grid Path
export PATH=$ORACLE_HOME/bin:$ORACLE_HOME/OPatch:$PATH

# Library Path
export LIBPATH=$ORACLE_HOME/lib:/usr/lib:$LIBPATH

# NLS Settings
export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"
export NLS_LANG=AMERICAN_AMERICA.AL32UTF8

# Shell Settings
export EDITOR=vi
set -o vi

# Aliases
alias asm='sqlplus / as sysasm'
alias crs='crsctl status resource -t'
alias crscheck='crsctl check cluster -all'
alias lsoh='$ORACLE_HOME/OPatch/opatch lspatches'

PS1='[grid@$(hostname):$ORACLE_SID] $ '

echo "Grid Infrastructure Environment Loaded"
EOF

chown grid:oinstall /home/grid/.profile
log_message "✅ Grid .profile configured"

# -----------------------------------------------
# STEP 6: Verify Users and Groups
# -----------------------------------------------
log_message ""
log_message "--- Verification ---"

log_message "Groups created:"
for GROUP in oinstall dba oper asmadmin asmdba asmoper; do
    lsgroup $GROUP | tee -a $LOG_FILE
done

log_message ""
log_message "Users created:"
lsuser oracle | tee -a $LOG_FILE
lsuser grid   | tee -a $LOG_FILE

log_message "============================================"
log_message "✅ Users and Groups Setup Complete"
log_message "============================================"
