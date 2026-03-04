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
# tweakable variables
# ================================================================== 
# n/a

# ================================================================== 
# Issue:
# Make a VM unable to boot to guest OS
# by setting its boor properties to UEFI
# ID in OneNote: 1.5_15.1
# new ID 5.15_1.1
# ================================================================== 
break_id="5.15_1.1"
echo `print_yellow " Here we will add the description of the issue the way it can be presented to the student.
 TODO: once the issue description is finalized in terms of wording a template will be seen here.
"`

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
# refer to zzz-variables.sh.conf for definitions

# for now we will assume Windows VM!
#vm_to_use=
if [ -z $1 ] ; then vm_to_use=${cluster_name}-windows-1 ; else vm_to_use=$1 ; fi
echo "We will break" `print_blue $vm_to_use`

echo -n "Checking if VM with the name"; print_blue "${vm_to_use}"; echo -n "exists and it is ... "
acli vm.list | grep ${vm_to_use} 2>&1 >/dev/null # will return 1 if grep does not find a match (true)
vm_missing=$?
if [ $vm_missing -eq 1 ] ; then print_red "missing." ; echo "Exiting ... (5)" ; exit 5 ; else print_green "present."; echo "" ; fi

# ================================================================== 
# Actual break
# change the VM config - to use UEFI boot
# ================================================================== 
vm_state=$(acli vm.get $vm_to_use | awk '/state/ { print $NF }' | tr -d \")

if [ -z $vm_state ]
  then
    echo `print_blue $vm_to_use`"is in unknown state:"`print_red $vm_state`"Attempting to shut it down!"
	acli vm.off $vm_to_use 2>&1 > /dev/null
    vm_state=$(acli vm.get $vm_to_use | awk '/state/ { print $NF }' | tr -d \")
  else
    if [ $vm_state == "kOn" ]
      then
        echo `print_blue $vm_to_use`"is in powered on! State:"`print_green $vm_state`
		echo "Attempting to shut it down!"
        acli vm.off $vm_to_use 2>&1 > /dev/null
        vm_state=$(acli vm.get $vm_to_use | awk '/state/ { print $NF }' | tr -d \")
    fi
fi

if [ $vm_state == "kOff" ]
 then
   echo `print_blue $vm_to_use`"is in state "`print_green kOff`"!"
 else
  echo `print_blue $vm_to_use`"is still not in state "`print_red kOff`"!"
  echo "Exiting ... (6)" ; ecit 6
fi

# if we got to here without exiting then vm is off
vm_uefi_status=$(acli vm.get $vm_to_use | awk '/uefi_boot/ { print tolower($NF)}')

if [ -z $vm_uefi_status ] || [ "$vm_uefi_status" == "false" ] 
 then
   echo `print_blue $vm_to_use`"is not uefi enabled."
   echo "Setting up UEFI boot for"`print_blue $vm_to_use`
   acli vm.update $vm_to_use uefi_boot=true 2>&1 > /dev/null
   vm_uefi_status=$(acli vm.get $vm_to_use | awk '/uefi_boot/ { print tolower($NF)}')
 else
   if [ $vm_uefi_status == "true" ]
    then
     echo "UEFI boot is already "`print_green enabled`"for"`print_blue $vm_to_use`
   fi
fi

echo `print_blue $vm_to_use`" has uefi_boot status"`print_red $vm_uefi_status`"now."
echo `print_fgred "[Fix]"`" To fix manually execute:"`print_blue "acli -y vm.update $vm_to_use uefi_boot=false"`"on any CVM" # the -y is important as otherwise acli will wait for confirmation of deleting the UEFI NVRAM
echo "All done"