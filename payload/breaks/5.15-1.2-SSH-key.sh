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
# Unable to login with provided key to the cluster
# ID in OneNote: 1.5_15.2
# new ID: 5.15_1.2
# ================================================================== 
break_id="5.15_1.2"

# ================================================================== 
# tweakable variables
# ================================================================== 
# n/a
payload_folder_name="payload/"
cvm_path="/home/nutanix/tmp/ntc/"
key_name="AdminKey"
key_name_prism="AdminKey"

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
# refer to zzz-variables.sh.conf for definitions

#generate the key
if [ -f ${cvm_path}${payload_folder_name}${key_name} ] && [ -f ${cvm_path}${payload_folder_name}${key_name}.pub ]
 then
  echo "A key already exists under"`print_green ${cvm_path}${payload_folder_name}${key_name}`"and will be reused"
  ls -l ${cvm_path}${payload_folder_name}${key_name}*
 else
  echo "No key found under"`print_blue ${cvm_path}${payload_folder_name}${key_name}`". Generating it..."
  ssh-keygen -t rsa -b 2048 -N "" -f ${cvm_path}${payload_folder_name}${key_name} 2>&1 > /dev/null
  if [ $? -eq 0 ] ; then echo "Keys genereated"`print_green "successfully"`"under"`print_blue ${cvm_path}${payload_folder_name}${key_name}`; else echo "Failed to create key pair. Exiting ... (7)" ; exit 7 ; fi
fi

# ================================================================== 
# Actual break
# upload the key to prism
# ================================================================== 
echo "Adding"`print_blue ${cvm_path}${payload_folder_name}${key_name}.pub`"to the cluster..."
ncli cluster add-public-key name="${key_name_prism}" file-path="${cvm_path}${payload_folder_name}${key_name}.pub" 2>&1 > /dev/null
if [ $? -eq 0 ]
 then
  echo `print_green "[Added]"`"successfully."
  echo "The key name used and shown in prism is"`print_blue $key_name_prism`
 else
  echo "Failed to upload the key to the cluster."`print_red "Exiting ... (8)"` ; exit 8
fi

echo `print_fgred "[Fix]"`" No need to fix anything since we need to only make sure we can login with the keys from the student/candidate desktop"
echo `print_fgred "[TODO]"`"Add ansible (or other) automation to put the public and private key generated on the desktop of the student (will need a way to determine which jumpbox that is (nslookup {cluster_name}-pc) and which student account). smbclient installed and configured. Could be used like this (obviously with paramters to fillout the local path and the remote file name depending on which student is being used):"`print_blue "smbclient //pandia-pc.learn.local/c$ Nutanix/4u! -U Student1@learn.local -c 'put /home/assen/tmp.sh Users\Student1\Desktop\tmp.sh'"`
