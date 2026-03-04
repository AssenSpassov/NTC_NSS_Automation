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
#
# ID in OneNote: 4.51 (old 5.15_4.1)
# ==================================================================
grade_id="4.51"

# ================================================================== 
# tweakable variables
# ================================================================== 
big_VM_name="importantVM-1"
big_VM_name1="importantVM-2"
big_important_VM_name="importantVM-3"

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
function print_fix() {
 echo `print_fgred [Fix]`" If you want to fix/reset the issue just delete the VMs with:"`print_blue "acli -y vm.delete $big_VM_name,$big_VM_name1,$big_important_VM_name"`
}

# ================================================================== 
# Actual grading
# ================================================================== 
echo "Checking if all VMs are on:"
VMs_ON=0 # initial assumtion is that they aren't

echo "Checking"`print_blue $big_VM_name`"..."
out=`acli vm.get $big_VM_name | awk '/state/ {print $2}' | tr -d \"`
if [[ $out == "kOn" ]] ; then echo `print_blue $big_VM_name`"is"`print_green "ON"`; VMs_ON=$(($VMs_ON+1)) ; else echo `print_blue $big_VM_name`"is"`print_red "OFF"` ; fi

echo "Checking"`print_blue $big_VM_name1`"..."
out=`acli vm.get $big_VM_name1 | awk '/state/ {print $2}' | tr -d \"`
if [[ $out == "kOn" ]] ; then echo `print_blue $big_VM_name1`"is"`print_green "ON"`; VMs_ON=$(($VMs_ON+1)) ; else echo `print_blue $big_VM_name1`"is"`print_red "OFF"` ; fi

echo "Checking"`print_blue $big_important_VM_name`"..."
out=`acli vm.get $big_important_VM_name | awk '/state/ {print $2}' | tr -d \"`
if [[ $out == "kOn" ]] ; then echo `print_blue $big_important_VM_name`"is"`print_green "ON"`; VMs_ON=$(($VMs_ON+1)) ; else echo `print_blue $big_important_VM_name`"is"`print_red "OFF"` ; fi

if [ $VMs_ON -lt 3 ] ;
 then 
  echo "Some VMs are OFF (only"`print_red $VMs_ON`" out of 3 are ON)!"
  echo "Scenario"`print_blue $grade_id`"grade is"`print_red "[FAIL]"`"Exiting ... (5)"
  print_fix
  exit 5
 elif [ $VMs_ON -eq 3 ]
 then 
  reservation_type=`acli ha.get | awk '/reservation_type/ {print $2}' | tr -d \"`
  if [[ $reservation_type == "kAcropolisHAReserveSegments" ]] ; then echo "All 3 VMs are"`print_green "ON"`"and HA is enabled with"`print_green "$reservation_type"`; echo "Scenario"`print_blue "$grade_id"`"grade is:"`print_green "[PASS]"`; exit 0 ; else echo "We have"`print_green $VMs_ON`"VMs ON, but HA is with state"`print_red $reservation_type` ; echo "Scenario"`print_blue $grade_id`"grade is"`print_red "[FAIL]"`"Exiting ... (5)" ; print_fix ; exit 5 ; fi
 else 
  echo "Unexpected number of VMs in ON state -"`print_red $VMs_ON`
  echo "Scenario"`print_blue $grade_id`"grade is"`print_red "[FAIL]"`"Exiting ... (10)"
  print_fix
  exit 10
fi