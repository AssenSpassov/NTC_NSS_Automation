#!/bin/bash

# author: Assen Spassov (as@nutanix.com)
# this file is meant to be copied over and executed on a CVM

# ================================================================== 
# initializing global variables
# ================================================================== 
if [ -d ./payload ] 
then
  if [ -f ./payload/zzz-functions.sh.conf ] && [ -f ./payload/zzz-variables.sh.conf ]
  then
   source "./payload/zzz-functions.sh.conf" $LAPRAS_MODE
   source "./payload/zzz-variables.sh.conf" $LAPRAS_MODE
    if [ -f ./payload/TESTING_MODE.marker ]
     then
      TESTING_MODE=1
    fi
  else 
   echo "Failed to import formatting functions and vars in $0 with $LAPRAS_MODE! and "`pwd`" Exiting ... (255)" ; exit 255
  fi
else 
  if [ -f ./zzz-functions.sh.conf ] && [ -f ./zzz-variables.sh.conf ]
  then
   source "./zzz-functions.sh.conf" $LAPRAS_MODE
   source "./zzz-variables.sh.conf" $LAPRAS_MODE
    if [ -f ./TESTING_MODE.marker ]
     then
      TESTING_MODE=1
    fi
  else 
   echo "Failed to import formatting functions and variables in $0 and "`pwd`" with $LAPRAS_MODE! Exiting ... (255)" ; exit 255
  fi
fi

# ================================================================== 
# tweakable variables
# ================================================================== 
windows_img_name="windows-base-ntc"
#windows_img_src_url="${base_repo_url}${win_img_on_repo}" # moved to zzz-variables.sh.conf
windows_vm_num_vcpus=2
windows_vm_num_cores_per_vcpu=1
windows_vm_memory="4G"
windows_user="Administrtor" # not used yet
windows_pw="nutanix/4u" # not used yet

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
# refer to zzz-variables.sh.conf for definitions
echo -n "We are going to create the following Linux VMs: "; for ntc_windows_vm in "${ntc_windows_vms[*]}"; do print_blue "$ntc_windows_vm"; done ; echo

echo -n "Checking for container named"; print_blue "${ntc_ctr_name}"; echo -n "and it is ... "
ncli ctr list name=${ntc_ctr_name} | grep ${ntc_ctr_name} 2>&1 >/dev/null # will return 1 if grep does not find a match (true)
ntc_ctr_missing=$?
if [ $ntc_ctr_missing -eq 1 ] ; then print_red "missing." ; echo "Will be created later." ; else print_green "present."; echo "" ; fi

echo -n "Checking for windows image named" ; print_blue "$windows_img_name"; echo -n "and it is ... "
windows_img_uuid=""
acli image.list | grep $windows_img_name 2>&1 >/dev/null
windows_img_missing=$?
if [ $windows_img_missing -eq 1 ] ; then print_red "missing." ; echo "Will be created later." ; else print_green "present."; echo "" ; fi


# ================================================================== 
# Container create + image upload <= with check if those exist
# the awk search for the string took ages because of the way bash
# works with vairable substitution.
# TODO: enhance or rework this awk workaround with the
# img_uuid_cmd variable
# ================================================================== 
img_uuid_cmd="acli image.list | awk '/${windows_img_name}/ {print \$NF}'" # needed in order to use to get the UUID within the if statement below
# ncli ctr create will give output for verification and log information
if [ $ntc_ctr_missing -eq 1 ] ; then print_blue ${ntc_ctr_name}; echo -n "is" ; print_red "missing." ; echo -n "Creating it..."; ncli ctr create name=${ntc_ctr_name} sp-name=${def_sp_name} ; if [ `echo $?` -eq 1 ] ; then print_red "Failed" ; else print_green "Done"; fi ; else print_blue ${ntc_ctr_name} ; echo -n "is" ; print_green "present." ; echo "Continuing ..."  ; fi

# THIS SOMEHOW FAILED WITH THE TASK REPORTING 100% completion
# need to make more robust:
# Windows image windows-base-ntc is missing . Creating it (sleep 10 before checking status of the task)...
# [ 2021/02/01-16:14:41 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:14:46 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:14:52 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:14:57 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:15:02 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:15:07 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:15:13 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:15:18 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:15:23 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:15:29 UTC ] Windows image image upload:  0 %
# [ 2021/02/01-16:15:34 UTC ] Windows image image upload:  100 %

if [ $windows_img_missing -eq 1 ]
  then
    echo -n "Windows image" ; print_blue ${windows_img_name} ; echo -n "is" ; print_red "missing" ; echo -n ". Creating it (sleep 10 before checking status of the task)... "
    acli image.create $windows_img_name source_url=${windows_img_src_url} container=$ntc_ctr_name image_type=kDiskImage wait=false
    sleep 10
    task_uuid=$(ecli task.list limit=20 | grep Running | grep Image | awk '{print $1}')
    task_completion=0

    monitor_task_progress $task_uuid "Uploading Windows image"

    echo ""
    windows_img_uuid=$(bash -lc "$img_uuid_cmd")
    echo -n "The Windows image" ; print_blue ${windows_img_name} ; echo -n "was created and has UUID = " ; print_blue ${windows_img_uuid} ; echo ""
    echo "windows_img_uuid=$windows_img_uuid" >> $ntc_vars_conf_file
  else
    windows_img_uuid=$(bash -lc "$img_uuid_cmd")
    grep windows_img_uuid $ntc_vars_conf_file 2>&1 > /dev/null
    if [ ! $? -eq 0 ] ; then echo "windows_img_uuid=$windows_img_uuid" >> $ntc_vars_conf_file ; fi
    echo -n "Windows image" ; print_blue ${windows_img_name} ; echo -n "is" ; print_green "present" ; echo -n "with UUID =" ; print_blue ${windows_img_uuid} ; echo ""
fi


# ================================================================== 
# Create the Windows VMs
# ================================================================== 
for windows_vm in "${ntc_windows_vms[@]}"
do
 print_yellow "======= Creating ${windows_vm}\n"
 acli vm.list | grep $windows_vm 2>&1 > /dev/null
 windows_vm_missing=$?
 if [ $windows_vm_missing -eq 1 ]
   then
    echo -n "Confirmed VM" ; print_blue $windows_vm ; echo -n "does not exists. Creating it with num_vcpus ="; print_blue ${windows_vm_num_vcpus} ; echo -n ", num_cores_per_vcpu =" ; print_blue ${windows_vm_num_cores_per_vcpu} ; echo -n "and memory =" ; print_blue ${windows_vm_memory} ; echo -n "on" ; print_blue ${ntc_ctr_name}; echo "..."
    acli vm.create $windows_vm num_vcpus=${windows_vm_num_vcpus} num_cores_per_vcpu=${windows_vm_num_cores_per_vcpu} memory=${windows_vm_memory}
	acli vm.disk_create ${windows_vm} cdrom=true empty=true
    acli vm.disk_create ${windows_vm} clone_from_image=${windows_img_name}
    acli vm.nic_create ${windows_vm} network=$dhcp_net_name
  else
     echo -n "VM with name"; print_blue $windows_vm ; echo -n "already exists.";  print_green "Nothing to do." ; echo ""
 fi
# acli vm.on $windows_vm
done