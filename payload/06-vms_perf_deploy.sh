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

# ================================================================== 
# tweakable variables
# ================================================================== 
perf_img_name="CentOS-perf-ntc"
#perf_img_src_url="${base_repo_url}${perf_img_on_repo}" # moved to zzz-variables.sh.conf
perf_vm_num_vcpus=4
perf_vm_num_cores_per_vcpu=1
perf_vm_memory="4G"
perf_vm_user="root" # not used yet
perf_vm_pw="Nutanix/4u!" # not used yet

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
echo -n "We are going to create the following Perf VMs: "; for ntc_perf_vm in "${ntc_perf_vms[*]}"; do print_blue "$ntc_perf_vm"; done ; echo

echo -n "Checking for container named"; print_blue "${ntc_ctr_name}"; echo -n "and it is ... "
ncli ctr list name=${ntc_ctr_name} | grep ${ntc_ctr_name} 2>&1 >/dev/null # will return 1 if grep does not find a match (true)
ntc_ctr_missing=$?
if [ $ntc_ctr_missing -eq 1 ] ; then print_red "missing." ; echo "Will be created later." ; else print_green "present."; echo "" ; fi

echo -n "Checking for Perf image with name '$perf_img_name' and it is ... "
perf_img_uuid=""
acli image.list | grep $perf_img_name 2>&1 >/dev/null
lnx_img_missing=$?
if [ $lnx_img_missing -eq 1 ] ; then print_red "missing." ; echo "Will be created later." ; else print_green "present."; echo "" ; fi


# ================================================================== 
# Container create + image upload <= with check if those exist
# the awk search for the string took ages because of the way bash
# works with vairable substitution.
# TODO: enxhance or rework this awk workaround with the
# img_uuid_cmd variable
# ================================================================== 
img_uuid_cmd="acli image.list | awk '/${perf_img_name}/ {print \$NF}'" # needed in order to use to get the UUID within the if statement below
if [ $ntc_ctr_missing -eq 1 ] ; then print_blue ${ntc_ctr_name}; echo -n "is" ; print_red "missing." ; echo -n "Creating it..."; ncli ctr create name=${ntc_ctr_name} sp-name=${def_sp_name} ; if [ `echo $?` -eq 1 ] ; then print_red "Failed" ; else print_green "Done"; fi ; else print_blue ${ntc_ctr_name} ; echo -n "is" ; print_green "present." ; echo "Continuing ..." ; fi

if [ $lnx_img_missing -eq 1 ]
  then
    echo -n "Perf image" ; print_blue ${perf_img_name} ; echo -n "is" ; print_red "missing" ; echo -n ". Creating it (sleep 10 after starting it before starting to display output)... "
	acli image.create $perf_img_name source_url=${perf_img_src_url} container=$ntc_ctr_name image_type=kDiskImage wait=false
	sleep 10
	task_uuid=$(ecli task.list limit=20 | grep Running | grep Image | awk '{print $1}')
	task_completion=0
	while [ $task_completion -lt 100 ] 
	do
	  task_completion=$(ecli task.get $task_uuid | grep "percentage_complete" | sed -e 's/,//g' |  awk '{print $NF}')
      echo "["`print_time`"] Perf image upload: "`print_blue "$task_completion"`"%"
      sleep 5
    done
	echo ""
    perf_img_uuid=$(bash -lc "$img_uuid_cmd")
	echo "perf_img_uuid=$perf_img_uuid" >> $ntc_vars_conf_file
    echo -n "The Perf image" ; print_blue ${perf_img_name} ; echo -n "was created and has UUID = " ; print_blue ${perf_img_uuid} ; echo ""
  else
    perf_img_uuid=$(bash -lc "$img_uuid_cmd")
	grep perf_img_uuid $ntc_vars_conf_file 2>&1 > /dev/null
	if [ ! $? -eq 0 ] ; then echo "perf_img_uuid=$perf_img_uuid" >> $ntc_vars_conf_file ; fi
    echo -n "Perf image" ; print_blue ${perf_img_name} ; echo -n "is" ; print_green "present" ; echo -n "with UUID =" ; print_blue ${perf_img_uuid} ; echo "" 
fi


# ================================================================== 
# Create the Perf VMs
# ================================================================== 
for perf_vm in "${ntc_perf_vms[@]}"
do
 print_yellow "======= Creating ${perf_vm}\n" ; echo ""
 acli vm.list | grep $perf_vm 2>&1 > /dev/null
 perf_vm_missing=$?
 if [ $perf_vm_missing -eq 1 ]
   then
    echo -n "Confirmed VM" ; print_blue $perf_vm ; echo -n "does not exist. Creating it with num_vcpus ="; print_blue ${perf_vm_num_vcpus} ; echo -n ", num_cores_per_vcpu =" ; print_blue ${perf_vm_num_cores_per_vcpu} ; echo -n "and memory =" ; print_blue ${perf_vm_memory} ; echo -n "on" ; print_blue ${ntc_ctr_name}; echo "..."
    acli vm.create $perf_vm num_vcpus=${perf_vm_num_vcpus} num_cores_per_vcpu=${perf_vm_num_cores_per_vcpu} memory=${perf_vm_memory}
	acli vm.disk_create ${perf_vm} cdrom=true empty=true
    acli vm.disk_create ${perf_vm} clone_from_image=${perf_img_name}
    acli vm.nic_create ${perf_vm} network=$dhcp_net_name
  else
     echo -n "VM with name"; print_blue $perf_vm ; echo -n "already exists." ; print_green "Nothing to do." ; echo ""
 fi
# acli vm.on $perf_vm
done