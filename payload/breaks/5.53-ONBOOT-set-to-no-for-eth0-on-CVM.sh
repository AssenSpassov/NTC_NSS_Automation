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
break_id="5.53"

# ================================================================== 
# tweakable variables
# ================================================================== 
ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
# refer to zzz-variables.sh.conf for definitions

# ================================================================== 
# Actual break
# replace ONBOOT param for eth0 on any CVM
# ================================================================== 
host_ip=$(hostips | awk '{print $1}')
cvm_ip=$(svmips | awk '{print $1}')
current_cvm_ip=$(ifconfig eth0 | awk '/inet / {print $2}')

if [ $cvm_ip == $current_cvm_ip ]
then 
 echo "Connected to the VM which will break, swithcing to a different one..." 
 cvm_ip=$(svmips | awk '{print $2}')
 host_ip=$(hostips | awk '{print $2}')
fi

echo "Breaking CVM with IP"`print_blue $cvm_ip`"on host"`print_blue $host_ip`
ssh $ssh_opts $cvm_ip "sudo sed -i 's/ONBOOT=\"yes\"/ONBOOT=\"no\"/g' /etc/sysconfig/network-scripts/ifcfg-eth0" 2>&1 > /dev/null
echo -n `print_time`"Verifying value of ONBOOT param"
ssh $ssh_opts $cvm_ip "sudo cat /etc/sysconfig/network-scripts/ifcfg-eth0 | grep ONBOOT"

if [ $LAPRAS_MODE_FUNC -eq 1 ] ; then confirmation="y" ; else echo -n "Confirm network restart on"`print_blue $cvm_ip`"as per above outputs... [y/N] " ; read confirmation ; fi

if [ -z $confirmation ] || [ $confirmation == "N" ] || [ $confirmation == "n" ] || [ $confirmation == "no" ] || [ $confirmation == "No" ]
 then
  echo "No option or simply 'No' selected. Cancelling and exiting ... (252)" ; exit 252
 elif [ $confirmation == "Y" ] || [ $confirmation == "y" ] || [ $confirmation == "yes" ] || [ $confirmation == "Yes" ]
  then
   echo "Restarting network on"`print_blue $cvm_ip`"where ONBOOT is set to no in ifcfg-eth0"
   ssh $ssh_opts $cvm_ip "sudo service network restart ; date" 2>&1 > /dev/null & 
 else
  echo `print_red "Invalid"`"option selected. Default is to not restart. Cancelling and exiting ... (251)" ; exit 251
fi

echo "Sleeping 20 seconds..." ; sleep 20
echo "Pinging"`print_blue $cvm_ip`
ping -c1 $cvm_ip 2>&1 >/dev/null

if [ $? -eq 1 ]
then
 echo `print_green "Ping failed"`"which is expected if the CVM is broken"
 echo "Scenario is broken"
else
 echo `print_red "Ping succeeded"`"which mens the CVM isreachable and not broken. Check status on"`print_blue $cvm_ip`". Exiting ... (11)" ; exit 11
fi

echo `print_fgred "[Fix]"`" Connect to the host where CVM(s)"`print_blue "$cvm_ip"`"is/are running and from there to the CVM itself with"`print_blue "ssh nutanix@192.168.5.254"`", then run"`print_blue "sudo sed -i 's/ONBOOT=\"no\"/ONBOOT=\"yes\"/g' /etc/sysconfig/network-scripts/ifcfg-eth0"`"and restart the network with"`print_blue "sudo service network restart"`
# TODO: implement a check on the ssh command and its status
