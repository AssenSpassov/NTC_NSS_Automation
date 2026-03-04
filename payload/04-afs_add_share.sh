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
# local tweakable variables
# ================================================================== 
domain="Learn.local"
domain_user="Administrator"
domain_pw=Nutanix/4u!
smb_share_name="${cluster_name}-smb-share"

# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 
# Those are from the global variables file above

# ================================================================== 
# Files AD reg and shares creation
# ================================================================== 
echo `print_yellow "============================================"`
echo `print_yellow "======= Configuring Files' shares:"`

echo "Checking for a running Files Deploment task:..."
deploy_files_task_uuid=`ecli task.list component_list=minerva_cvm | awk '/FileServerAdd/ {print $1}'`
# If there were multiple tasks, get the newest
if [ `echo $ deploy_files_task_uuid | wc -w` -gt 1 ] ; then deploy_files_task_uuid=`echo $deploy_files_task_uuid | awk '{print $1}'`; fi

deploy_files_task_status=`ecli task.get $deploy_files_task_uuid | awk '/status/ {print $NF}' | tr -d \, | tr -d \"`
if [ -z $deploy_files_task_uuid ] || [ -z $deploy_files_task_status ]
 then
  echo `print_red "[Failed]"`"to get task UUID or status. Cannot make decision! Exiting ... (253)"
  echo "deploy_files_task_uuid = $deploy_files_task_uuid"
  echo "deploy_files_task_status = $deploy_files_task_status"
  exit 253
fi

if [ $deploy_files_task_status == "kRunning" ]
 then
  task_completion=0
  echo -n "Task with UUID"`print_blue $deploy_files_task_uuid`"is still running. Completion:"
  while [ $task_completion -lt 100 ] 
  do
   task_completion=$(ecli task.get $deploy_files_task_uuid | grep "percentage_complete" | sed -e 's/,//g' |  awk '{print $NF}')
    echo "["`print_time`"] Files deplyment at"`print_blue "$task_completion"`"%"
   sleep 5
  done
fi

# refresh the status after the task completes
# TODO: when the deployments has been done multiple  times the below status command
# might be misleading (more than 1 hit), so I might need to modify the command (add limit=5?)
# nutanix@NTNX-14SM36030031-D-CVM:10.63.70.41:~$ ecli task.list status_list=kSucceeded component_list=minerva_cvm
# Task UUID                             Parent Task UUID                      Component    Sequence-id  Type                Status
# 9ce7849c-06b6-492d-b896-c34836d48634  6fe54f66-903e-4066-9e81-dcbddb3103b5  minerva_cvm  5            FileServerProtect   kSucceeded
# b12dd0b1-a876-4ada-9ac2-f280c19e1919  6fe54f66-903e-4066-9e81-dcbddb3103b5  minerva_cvm  4            FileServerVmDeploy  kSucceeded
# 84c291ef-99bf-46d0-a021-2dd0a8e6cb1d  6fe54f66-903e-4066-9e81-dcbddb3103b5  minerva_cvm  3            FileServerVmDeploy  kSucceeded
# 090db2e3-b06c-4d17-8c81-878c367008eb  6fe54f66-903e-4066-9e81-dcbddb3103b5  minerva_cvm  2            FileServerVmDeploy  kSucceeded
# 6fe54f66-903e-4066-9e81-dcbddb3103b5                                        minerva_cvm  1            FileServerAdd       kSucceeded
# nutanix@NTNX-14SM36030031-D-CVM:10.63.70.41:~$

deploy_files_task_status=`ecli task.get $deploy_files_task_uuid | awk '/status/ {print $NF}' | tr -d \, | tr -d \"`
if [ $deploy_files_task_status == "kSucceeded" ]
 then
  echo "Task for deployment has"`print_green "succeeded"`". UUID is"`print_blue $deploy_files_task_uuid`". Continue to add shares..."
 else
  echo "Reported status for task UUID"`print_blue $deploy_files_task_uuid`"is"`print_red $deploy_files_task_status`
  echo `print_red "Failed"`"to determine Files deployment status (different than kRunning or kSucceeded). Exiting ... (252)" ; exit 252
fi

ncli fs ls | grep -i ${cluster_name}-FS 2>&1 >/dev/null
files_missing=$?
if [ $files_missing -eq 1 ]
 then
  echo "Nutanix Files instance is"`print_red "missing."`
  echo "Cannot create shares on missing instance! Exiting ... (254)" ; exit 254
 else
  echo "Nutanix Files instance is"`print_green "present."`
fi

fs_uuid=$(ncli fs ls | awk '/Uuid/ {print $NF}' | head -n1)
echo "Files UUID for ${cluster_name} is"`print_blue "${fs_uuid}"`
echo "fs_uuid=$fs_uuid" >> $ntc_vars_conf_file

echo "Querying"`print_blue $fs_uuid`"to check if"`print_blue $smb_share_name`"exists..."
ncli fs list-shares uuid=$fs_uuid | grep $smb_share_name
fs_share_exits=$?
if [ $fs_share_exits -eq 1 ]
 then
  echo "Share with name"`print_blue $smb_share_name`"does not exist on"`print_blue $fs_uuid`". Will join domain, etc. and create it now..."
  
  echo -n "Checking if Files is already part of $domain ..."  
  ncli fs ls | head -n 20 | grep AD | grep $domain 2>&1 >> /dev/null
  if [ ! $? -eq 0 ] ; then echo -n "Not part ... Joining Files to AD and sleeping 20: ...";  ncli fs join-domain uuid=${fs_uuid} windows-ad-domain-name="$domain" windows-ad-username="$domain_user" windows-ad-password="$domain_pw" overwrite="true" ; sleep 10 ; fi

  echo -n "Checking if Files joined the domain $domain ..."  
  ncli fs ls | head -n 20 | grep AD | grep $domain 2>&1 >> /dev/null
  if [ ! $? -eq 0 ] ; then echo -n "Still not joined ... Exiting ... (251)"; exit 251 ; else echo `print_green "[Done]"` ; fi

  echo "Adding admin user for Files (${fs_uuid}): ..."
  ncli fs add-admin-user uuid=${fs_uuid} user=$domain_user role=ADMIN 2>&1 >/dev/null
  print_green "[Done]" ; echo

  echo "Creating ${smb_share_name} on ${cluster_name}: ..."
  ncli fs add-share uuid=${fs_uuid} name=$smb_share_name share-type=General share-size-gib=1024 enable-access-based-enumeration=true protocol-type=SMB enable-windows-previous-version=true 2>&1 >/dev/null
  print_green "[Done]" ; echo

  echo -n "Getting the properties of the task:"
  task_id=$(ecli task.list limit=10 | grep miner | grep Share | awk '{print $1}')
  print_blue $task_id; echo
 else
  echo "Share with name"`print_blue $smb_share_name`"already present on"`print_blue $fs_uuid`"Skipping setup..."
fi