#!/bin/bash

# author: Assen Spassov (as@nutanix.com)
# this file is meant to be copied over and executed on a CVM

# ================================================================== 
# importing global variables and functions
# ================================================================== 
if [ -d ./payload ] 
then
  if [ -f ./payload/zzz-functions.sh.conf ] && [ -f ./payload/zzz-variables.sh.conf ]
  then
   source "./payload/zzz-functions.sh.conf"
   source "./payload/zzz-variables.sh.conf"
   echo "Imported settings from ./payload/*.conf"
  else 
   echo "Failed to import formatting functions and vars in $0! and "`pwd`" Exiting ... (255)" ; exit 255
  fi
else 
  if [ -f ./zzz-functions.sh.conf ] && [ -f ./zzz-variables.sh.conf ]
  then
   source "./zzz-functions.sh.conf"
   source "./zzz-variables.sh.conf"
   echo "Imported settings from ./*.conf"
  else 
   echo "Failed to import formatting functions and variables in $0 and "`pwd`"! Exiting ... (255)" ; exit 255
  fi
fi

# ==================================================================
# Issue:
# Cannot enable HA due to affinity rules and big VMs
#
# Assumptions:
# - all hosts have the same memory configuration
# -
#
# ID in OneNote: 4.51 (old 5.15_4.1)
# ==================================================================
fix_reset_id="4.51"

# ================================================================== 
# tweakable variables
# ================================================================== 
big_VM_name="importantVM-1"
big_VM_name1="importnaVM-2"
big_important_VM_name="importantVM-3"

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
# refer to zzz-variables.sh.conf for definitions
#hosts=(`hostips`)
#memory=(`for host in $hosts ; do ssh root@$host "free -g | awk '/Mem/ {print \$2}'" 2>/dev/null`)

# ================================================================== 
# Actual reset:
# delete all the VMs to get a clean cluster
# ================================================================== 
echo "This is a hard reset script ..."
echo "[Powering off] all 3 VMs..."
acli -y vm.off $big_VM_name,$big_VM_name1,$big_important_VM_name
echo "[Powered off]"

echo "[Deleting] all 3 VMs..."
acli -y vm.delete $big_VM_name,$big_VM_name1,$big_important_VM_name
echo "[Deleted]"

echo "[Disable] HA ..."
acli ha.update num_host_failures_to_tolerate=0
echo "[Deleted]"