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
break_id="4.51"

# ================================================================== 
# tweakable variables
# ================================================================== 
big_VM_name="importantVM-1"
big_VM_name1="importantVM-2"
big_important_VM_name="importantVM-3"

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
# refer to zzz-variables.sh.conf for definitions
#hosts=(`hostips`)
#memory=(`for host in $hosts ; do ssh root@$host "free -g | awk '/Mem/ {print \$2}'" 2>/dev/null`)

# ================================================================== 
# Actual break
# Create the VMs, power them on.
# ================================================================== 

echo "[Disable] HA, if at all enabled ..."
acli ha.update num_host_failures_to_tolerate=0
echo "[Disabled] HA"

echo "Getting host memory..."
host_mem=$(ssh root@192.168.5.1 "free -g | awk '/Mem/ {print \$2}' 2>&1" 2>&1 | tail -n1)
mem=$host_mem
delta=5

vm_off=1
while [ $vm_off -eq 1 ]
do
 mem=$(($mem-$delta))
 acli vm.create "$big_VM_name" num_vcpus=4 memory=${mem}G 2>&1 > /dev/null
 # the below command will get the last 2 words from the output, if the VM was able to power on
 # they will contain the word "complete" other wise they will have approximately the max mem size
 # which could be used
 echo "[Starting]"`print_blue "$big_VM_name"`"with"`print_blue $mem`"GB of RAM, and"`print_blue "4"`"VCPUs..."
 vm_on_output=$(acli vm.on $big_VM_name | awk '{ if (NF > 1) print $(NF-1),$NF ; else print $NF; }')
 echo $vm_on_output | grep "complete" 2>&1 >/dev/null
 if [ $? -eq 0 ]
  then
   needed_mem=$(($mem/4))
   echo "Setting annotation for the second VM memory: as \"This VM only needs"`print_blue $needed_mem`"GB of memory and no affinity.\" "
   acli vm.update $big_VM_name annotation="This VM only needs $needed_mem GB of memory and does not need affinity." 2>&1 > /dev/null
   
   host_for_aff=`acli vm.get $big_VM_name | awk '/host_name/ { print $NF }' | tr -d \"`
   echo `print_blue $big_VM_name`"is currently running on"`print_blue $host_for_aff`
   echo `print_green "[Setting affinity]"`"for"`print_blue $big_VM_name`"on"`print_blue "$host_for_aff"`
   affinity_set_output=$(acli vm.affinity_set $big_VM_name host_list="${host_for_aff}")
   echo "$affinity_set_output" | grep complete
   if [ $? -eq 0 ] ; then print_green "[Affinity set]" ; echo "" ; else print_red "[Affinity failed]" ; echo "Exiting ... (10)" ; exit 10 ; fi
   
   echo `print_green "[Started]"``print_blue $big_VM_name`
   echo `print_green "[Create]"`"one more bigVM -"`print_blue $big_VM_name1`"with the same properties"
   acli vm.create "$big_VM_name1" num_vcpus=4 memory=${mem}G 2>&1 > /dev/null
   vm1_on_output=$(acli vm.on $big_VM_name1 | awk '{ if (NF > 1) print $(NF-1),$NF ; else print $NF; }')
   echo $vm1_on_output | grep "complete" 2>&1 >/dev/null
   if [ $? -eq 0 ]
    then
     echo "Setting annotation for the second VM memory: as \"This VM only needs"`print_blue $needed_mem`"GB of memory and no affinity.\" "
     acli vm.update $big_VM_name1 annotation="This VM only needs $needed_mem GB of memory and does not need affinity." 2>&1 > /dev/null
     echo `print_green [Started]``print_blue $big_VM_name1`
    else
     echo `print_red "[Start failed]"`"for"`print_blue $big_VM_name1`
   fi
   break
  else
   echo `print_red "[Start failed]"`
   echo "Deleteing"`print_blue $big_VM_name`"..."
   vm_delete_output=$(acli -y vm.delete "$big_VM_name" 2>&1)
   echo $vm_delete_output | grep "complete" 2>&1 >/dev/null
   if [ $? -eq 0 ] ; then print_green "[Deleted]" ; echo "" ; else print_red "[Delete failed]" ; echo "Exiting ... (9)" ; exit 9 ; fi
   continue
 fi
done

important_vm_memory=$(($host_mem-$mem+$delta))
echo `print_green "[Create]"`"the important VM"`print_blue $big_important_VM_name`"with"`print_blue $important_vm_memory`"GB of RAM"
acli vm.create "$big_important_VM_name" num_vcpus=4 memory=${important_vm_memory}G 2>&1 > /dev/null
important_vm_on_output=$(acli vm.on $big_important_VM_name | awk '{ if (NF > 1) print $(NF-1),$NF ; else print $NF; }')
echo $important_vm_on_output | grep "complete" 2>&1 >/dev/null
if [ $? -eq 0 ]
 then
  needed_mem=$(($important_vm_memory/3+1))
  acli vm.update $big_important_VM_name annotation="This VM only needs $needed_mem GB of memory." 2>&1 > /dev/null
  echo `print_green [Started]``print_blue $big_important_VM_name`
 else
  echo `print_red "[Start failed]"`"for"`print_blue $big_important_VM_name`
fi

# Stopping Files to free up resources
# Need to get the cluster name here instead of using the variables
# because of current variation in _C_lustername vs. _c_lustername
# this has been corrected in the FS json, but will take effect
# on next deployment
# echo `print_green "[Stop]"`"the VMs for the Files server to free resources. This will disregard their current status."
# acli vm.off NTNX-$(ncli cluster info | awk '/Name/ {print $NF}')-FS* 2>&1 > /dev/null
# echo `print_green "[Stopped]"`

host_list=$(hostips | awk '{print $1","$2}')
# need to ensure the host where the important VM was able to start is used for the affinity list (next 3 lines)
host_for_aff=`acli vm.get $big_important_VM_name | awk '/host_name/ { print $NF }' | tr -d \"`
echo `print_blue $big_important_VM_name`"is currently running on"`print_blue $host_for_aff`
echo $host_list | grep $host_for_aff 2>&1 > /dev/null
if [ $? -eq 1 ] ; then host_list=$(hostips | awk '{print $1","$3}') ; fi

echo `print_green "[Setting affinity]"`"for"`print_blue $big_important_VM_name`"on"`print_blue "$host_list"`
affinity_set_output=$(acli vm.affinity_set $big_important_VM_name host_list="${host_list}")
echo "$affinity_set_output" | grep complete
if [ $? -eq 0 ] ; then print_green "[Affinity set]" ; echo "" ; else print_red "[Affinity failed]" ; echo "Exiting ... (10)" ; exit 10 ; fi

echo "Trying to"`print_green [enable]`"HA with:"`print_blue "acli ha.update num_host_failures_to_tolerate=1"`
print_yellow "`acli ha.update num_host_failures_to_tolerate=1`" ; echo
echo "If you see a msg about InvalidState then the scenario is broken properly" ; echo
echo `print_green "[Executing]"``print_blue "acli.ha.get"`
acli ha.get
echo `print_green [Executed]`

echo `print_fgred [Fix]`" If you want to reset the issue just delete the VMs with:"`print_blue "acli -y vm.delete $big_VM_name,$big_VM_name1,$big_important_VM_name"`

# Need to work a bit more on making sure VM can start after the VM rules have been relaxed a bit since at the moment even after removing the affinity rule HA will not update with this:
# <acropolis> ha.update num_host_failures_to_tolerate=1
# HaUpdate: NoHostResources: Could not allocate resources to protect against 1 host failures. Free up more resources or relax some VMs' affinity policies.

# echo "Out of the loop"