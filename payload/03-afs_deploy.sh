#!/bin/bash

# author: Assen Spassov (as@nutanix.com)
# this file is meant to be copied over and executed on a CVM

# ==================================================================
# importing global variables
# ==================================================================
if [ -d ./payload ]
then
  if [ -f ./payload/zzz-functions.sh.conf ] && [ -f ./payload/zzz-variables.sh.conf ]
  then
   source "./payload/zzz-functions.sh.conf"
   source "./payload/zzz-variables.sh.conf"
  else
   echo "Failed to import formatting functions and vars in $0! and "`pwd`" Exiting ... (255)" ; exit 255
  fi
else
  if [ -f ./zzz-functions.sh.conf ] && [ -f ./zzz-variables.sh.conf ]
  then
   source "./zzz-functions.sh.conf"
   source "./zzz-variables.sh.conf"
  else
   echo "Failed to import formatting functions and variables in $0 and "`pwd`"! Exiting ... (255)" ; exit 255
  fi
fi

# ================================================================== 
# tweakable variables
# ================================================================== 
# all moved to the global file
payload_folder_name="payload/"
payload_config_file_Files="${cluster_name}.json"

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
# all moved to the global file

# ================================================================== 
# Files deloyment
# ================================================================== 
echo -n "Checking if Files is already deployed with name"`print_blue ${cluster_name}-FS`"and it is ... "
files_missing=""
ncli fs ls | grep -i ${cluster_name}-FS 2>&1 >/dev/null
files_missing=$?
if [ $files_missing -eq 1 ]
 then print_red "missing." ; echo "Will be created now."
 chmod +x $0.py
 dirname_path=`dirname $0`
 if [ -d $dirname_path ]
  then
   echo "Deploy using command:"`print_blue "$0.py -fn ${dirname_path}/afs_cluster_configs/${cluster_name}.json"`
   $0.py -fn ${dirname_path}/afs_cluster_configs/${cluster_name}.json
  else
   echo "Deploy using command:"`print_blue "$0.py -fn afs_cluster_configs/${cluster_name}.json"`
   $0.py -fn afs_cluster_configs/${cluster_name}.json
 fi
else
 print_green "present."; echo
 echo "Nothing to do... Exiting ... (0)"
fi

