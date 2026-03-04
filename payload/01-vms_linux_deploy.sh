#!/bin/bash

# author: Assen Spassov (as@nutanix.com)
# this file is meant to be copied over and executed on a CVM

# ================================================================== 
# LAPRAS specific section
# ================================================================== 
function usage {
        echo "./$(basename $0) -h anything --> shows usage"
        echo "./$(basename $0) -L 1 --> use when executed from lapras to suppres colors"
}

# list of arguments expected in the input
optstring=":h:L:"

# should be set to "-L 1" in the code if called trough Lapras
# then passed to the inheriting scripts
LAPRAS_MODE=""

while getopts ${optstring} arg; do
  case ${arg} in
    h)
      usage
      ;;
    L)
      if [ $OPTARG -eq 1 ] ; then LAPRAS_MODE="-L 1" ; fi
      #echo "paramter -L for Lapras suppiled with value: ${OPTARG}"
     ;;
    :)
      echo "$0: Must supply an argument to -$OPTARG." >&2
      exit 1
      ;;
    ?)
      echo "Invalid option: -${OPTARG}."
      exit 2
      ;;
  esac
done

# ================================================================== 
# END LAPRAS specific section
# ================================================================== 

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

if [ -f ./TESTING_MODE.marker ]
then
  TESTING_MODE=1
fi
  

# ================================================================== 
# tweakable variables from zzz-variables.sh.conf
# ================================================================== 
lnx_img_name="lnx-base-ntc"
#lnx_img_src_url="${base_repo_url}${lnx_img_on_repo}" # moved to zzz-variables.sh.conf
lnx_vm_num_vcpus=2
lnx_vm_num_cores_per_vcpu=1
lnx_vm_memory="4G"
lnx_user="root" # not used yet
lnx_pw="nutanix/4u" # not used yet

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
echo -n "We are going to create the following Linux VMs: "; for ntc_lnx_vm in "${ntc_lnx_vms[*]}"; do print_blue "$ntc_lnx_vm"; done ; echo

echo -n "Checking for container named"; print_blue "${ntc_ctr_name}"; echo -n "and it is ... "
ncli ctr list name=${ntc_ctr_name} | grep ${ntc_ctr_name} 2>&1 >/dev/null # will return 1 if grep does not find a match (true)
ntc_ctr_missing=$?
if [ $ntc_ctr_missing -eq 1 ] ; then print_red "missing." ; echo "Will be created later." ; else print_green "present."; echo "" ; fi

echo -n "Checking for Linux image with name '$lnx_img_name' and it is ... "
lnx_img_uuid=""
acli image.list | grep $lnx_img_name 2>&1 >/dev/null
lnx_img_missing=$?
if [ $lnx_img_missing -eq 1 ] ; then print_red "missing." ; echo "Will be created later." ; else print_green "present."; echo "" ; fi


# ================================================================== 
# Container create + image upload <= with check if those exist
# the awk search for the string took ages because of the way bash
# works with vairable substitution.
# TODO: enxhance or rework this awk workaround with the
# img_uuid_cmd variable
# ================================================================== 
img_uuid_cmd="acli image.list | awk '/${lnx_img_name}/ {print \$NF}'" # needed in order to use to get the UUID within the if statement below
if [ $ntc_ctr_missing -eq 1 ] ; then print_blue ${ntc_ctr_name}; echo -n "is" ; print_red "missing." ; echo -n "Creating it..."; ncli ctr create name=${ntc_ctr_name} sp-name=${def_sp_name} ; if [ `echo $?` -eq 1 ] ; then print_red "Failed" ; else print_green "Done"; fi ; else print_blue ${ntc_ctr_name} ; echo -n "is" ; print_green "present." ; echo "Continuing ..." ; fi

if [ $lnx_img_missing -eq 1 ]
  then
    echo -n "Linux image" ; print_blue ${lnx_img_name} ; echo -n "is" ; print_red "missing" ; echo -n ". Creating it (sleep 10 after starting it before starting to display output)... "
	  acli image.create $lnx_img_name source_url=${lnx_img_src_url} container=$ntc_ctr_name image_type=kDiskImage wait=false
	  sleep 10
	  task_uuid=$(ecli task.list limit=20 | grep Running | grep Image | awk '{print $1}')
	  task_completion=0

    monitor_task_progress $task_uuid "Uploading Linux image"

	  echo ""
      lnx_img_uuid=$(bash -lc "$img_uuid_cmd")
	  echo "lnx_img_uuid=$lnx_img_uuid" >> $ntc_vars_conf_file
    echo -n "The Linux image" ; print_blue ${lnx_img_name} ; echo -n "was created and has UUID = " ; print_blue ${lnx_img_uuid} ; echo ""
  else
    lnx_img_uuid=$(bash -lc "$img_uuid_cmd")
	  grep lnx_img_uuid $ntc_vars_conf_file 2>&1 > /dev/null
	if [ ! $? -eq 0 ] ; then echo "lnx_img_uuid=$lnx_img_uuid" >> $ntc_vars_conf_file ; fi
    echo -n "Linux image" ; print_blue ${lnx_img_name} ; echo -n "is" ; print_green "present" ; echo -n "with UUID =" ; print_blue ${lnx_img_uuid} ; echo "" 
fi


# ================================================================== 
# Create the Linux VMs
# ================================================================== 
for lnx_vm in "${ntc_lnx_vms[@]}"
do
 print_yellow "======= Creating ${lnx_vm}\n"
 acli vm.list | grep $lnx_vm 2>&1 > /dev/null
 lnx_vm_missing=$?
 if [ $lnx_vm_missing -eq 1 ]
   then
    echo -n "Confirmed VM" ; print_blue $lnx_vm ; echo -n "does not exist. Creating it with num_vcpus ="; print_blue ${lnx_vm_num_vcpus} ; echo -n ", num_cores_per_vcpu =" ; print_blue ${lnx_vm_num_cores_per_vcpu} ; echo -n "and memory =" ; print_blue ${lnx_vm_memory} ; echo -n "on" ; print_blue ${ntc_ctr_name}; echo "..."
    if [[ ! "$lnx_cloudinit_script_url" == *"TBD"* ]]
     then
      echo "Cloudinit script is present - will be used."
      acli uhura.vm.create_with_customize ${lnx_vm} container=${ntc_ctr_name} cloudinit_userdata_path="${lnx_cloudinit_script_url}" num_vcpus=${lnx_vm_num_vcpus} num_cores_per_vcpu=${lnx_vm_num_cores_per_vcpu} memory=${lnx_vm_memory}
    else
     acli vm.create $lnx_vm num_vcpus=${lnx_vm_num_vcpus} num_cores_per_vcpu=${lnx_vm_num_cores_per_vcpu} memory=${lnx_vm_memory}
    fi
	  acli vm.disk_create ${lnx_vm} cdrom=true empty=true
    acli vm.disk_create ${lnx_vm} clone_from_image=${lnx_img_name}
    acli vm.nic_create ${lnx_vm} network=$dhcp_net_name
  else
     echo -n "VM with name"; print_blue $lnx_vm ; echo -n "already exists." ; print_green "Nothing to do." ; echo ""
 fi
# acli vm.on $lnx_vm
done