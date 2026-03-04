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
   echo "Imported settings and vars from ./payload/*.conf"
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

# here we have already LAPRAS_MODE_FUNC defined in the zzz-functions file
# this can be used for the confirmation prompts

# ================================================================== 
# Issue:
# ONBOOT-set-to-no-for-eth0-on-CVM
# 2020-11-11 23:29 CET ID in OneNote: 5.53 (old 5.15_5.3)
# ================================================================== 
grade_id="5.53"

# ================================================================== 
# tweakable variables
# ================================================================== 
ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
# refer to zzz-variables.sh.conf for definitions
function print_fix () {
 echo `print_fgred "[Fix]"`" Connect to the host where CVM"`print_blue "$@"`"is/are running and from there to the CVM itself with"`print_blue "ssh nutanix@192.168.5.254"`", then run"`print_blue "sudo sed -i 's/ONBOOT=\"no\"/ONBOOT=\"yes\"/g' /etc/sysconfig/network-scripts/ifcfg-eth0"`"and restart the network with"`print_blue "sudo service network restart"`
}


# ================================================================== 
# Actual grade
# check that all CVMs are reachable
# ================================================================== 
cvmips=`svmips`
num_of_cvms=`echo $cvmips | wc -w`
reachable_cvms_count=0 # assume all CVMs are not reachable
unreachable_cvms=""

for cvm_ip in $cvmips 
do
# $IP comes from the CVM environment and is not defined anywhere in my scripting
 echo "Checking"`print_blue $cvm_ip`"via ping from "`print_blue $IP`"..."
 ping -c 1 $cvm_ip 2>&1 > /dev/null
 if [ $? -eq 0 ] ; then reachable_cvms_count=$(($reachable_cvms_count+1)) ; echo `print_blue $cvm_ip`"is"`print_green "reachable"` ; else echo `print_blue $cvm_ip`"is"`print_red "NOT reachable"` ; unreachable_cvms=$unreachable_cvms" $cvm_ip" ; fi
done

if [ ! $reachable_cvms_count -eq $num_of_cvms ]
then
 echo "Only"`print_red $reachable_cvms_count`"out of"`print_blue $num_of_cvms`"CVMs are reachable. Not checking ONBOOT on any of surviving VMs."
 print_fix $unreachable_cvms
 echo "Scenario"`print_blue $grade_id`"grade is"`print_red "[FAIL]"`"Exiting ... (10)"
 exit 10
fi

onboot_correct_count=0
echo "All"`print_green $reachable_cvms_count`"of"`print_blue $num_of_cvms`"CVMs are"`print_green "reachable"`". Checking ONBOOT on all CVMs."
for cvm_ip in $cvmips
do
 ssh $ssh_opts $cvm_ip "grep ONBOOT /etc/sysconfig/network-scripts/ifcfg-eth0 | grep 'yes'" 2>&1 > /dev/null
 if [ ! $? -eq 0 ]
  then
   echo "grep on"`print_blue $cvm_ip`"CVM did not find ONBOOT=yes (with or without quotes). It found:"
   ssh $ssh_opts $cvm_ip "grep ONBOOT /etc/sysconfig/network-scripts/ifcfg-eth0"
   print_fix $cvm_ip
   echo "Scenario"`print_blue $grade_id`"grade is"`print_red "[FAIL]"`"Exiting ... (11)"
   exit 11
 fi
 onboot_correct_count=$(($onboot_correct_count+1))
done

echo "All"`print_green $onboot_correct_count`"of"`print_blue $num_of_cvms`"are reachable and have ONBOOT=yes"
echo "Scenario"`print_blue "$grade_id"`"grade is:"`print_green "[PASS]"`
exit 0