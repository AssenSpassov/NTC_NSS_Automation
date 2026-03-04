#!/bin/bash

# author: Assen Spassov (as@nutanix.com)
# this file is meant to be copied over and executed on a CVM

### TODO: move here all prereq actions, like creating container, uploading images and similar...

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
# importing global variables
# ================================================================== 
if [ -d ./payload ] 
then
  if [ -f ./payload/zzz-functions.sh.conf ] && [ -f ./payload/zzz-variables.sh.conf ]
  then
   source "./payload/zzz-functions.sh.conf" $LAPRAS_MODE
   source "./payload/zzz-variables.sh.conf" $LAPRAS_MODE
  else 
   echo "Failed to import formatting functions and vars in $0 with $LAPRAS_MODE! and "`pwd`" Exiting ... (255)" ; exit 255
  fi
else 
  if [ -f ./zzz-functions.sh.conf ] && [ -f ./zzz-variables.sh.conf ]
  then
   source "./zzz-functions.sh.conf" $LAPRAS_MODE
   source "./zzz-variables.sh.conf" $LAPRAS_MODE
  else 
   echo "Failed to import formatting functions and variables in $0 and "`pwd`" with $LAPRAS_MODE! Exiting ... (255)" ; exit 255
  fi
fi

# ==================================================================
# tweakable variables
# ==================================================================
virtual_switch="vs0"

# ==================================================================
#  local derived cluster specific variables
# ==================================================================
# getting the local cluster PW from the json file and in the config!
if [ -f $ntc_vars_conf_file ]
then
 cat $ntc_vars_conf_file | grep ssh_password 2>&1 > /dev/null
 if [ $? -eq 1 ]
 then
  ssh_password=`cat /home/nutanix/tmp/ntc/payload/afs_cluster_configs/${cluster_name}.json | awk '/pass/ {print $NF}'  |tr -d \" | tr -d \,`
  echo "ssh_password=$ssh_password" >> $ntc_vars_conf_file
  curl_auth=`echo admin:$ssh_password | base64`
  echo "curl_auth=$curl_auth" >> $ntc_vars_conf_file
 fi
fi

 
# ==================================================================
# Deploy SSH keys
# ==================================================================
echo "Deploying the SSH key is handled in the orchestrator script... "

# ==================================================================
# Create Rest API user
# ==================================================================
echo `print_green "[Create]"`"a rest-API user"`print_blue "rest_api_user"`
ncli user list user-name=$rest_api_user | grep $rest_api_user 2>&1 > /dev/null
if [ $? -eq 0 ]
 then
  echo `print_green "[Exists]"`"... Nothing to do..."
 else
  echo `print_yellow "[Creating]"`"..."`ncli user add user-name=${rest_api_user} first-name=rest last-name=api email-id=${rest_api_user}@example.com user-password=$ssh_password 2>&1 > /dev/null``print_green "[Done]"`
  echo `print_yellow [Granting]`"needed admin roles ..."`ncli user grant-cluster-admin-role user-name=${rest_api_user} 2>&1 > /dev/null``ncli user grant-user-admin-role user-name=${rest_api_user} 2>&1 > /dev/null``print_green "[Done]"`
fi

# ==================================================================
# Create networks
# ==================================================================
# DHCP network (102)
acli net.list | grep ${dhcp_net_name} 2>&1 > /dev/null
if [ $? -eq 1 ]
then
 echo `print_blue ${dhcp_net_name}`"is"`print_red "missing"`". Creating it with VLAN ID"`print_blue ${dhcp_net_VLAN_ID}`
 acli net.create ${dhcp_net_name} vlan=${dhcp_net_VLAN_ID} virtual_switch=${virtual_switch}
 echo "  "`print_green "[Done]"`
else
 echo `print_blue ${dhcp_net_name}`"is"`print_green "present"`"with VLAN ID"`print_blue ${dhcp_net_VLAN_ID}`". Will reuse it..."`print_red "Check its settings."`
fi

# MGMT network native (0) - not managed
acli net.list | grep ${native_net_name_notmanaged} 2>&1 > /dev/null
if [ $? -eq 1 ]
then
 echo `print_blue ${native_net_name_notmanaged}`"is"`print_red "missing"`". Creating it with VLAN ID"`print_blue ${native_net_VLAN_ID_notmanaged}`
 acli net.create ${native_net_name_notmanaged} vlan=${native_net_VLAN_ID_notmanaged} virtual_switch=${virtual_switch}
 echo "  "`print_green "[Done]"`
else
 echo `print_blue ${native_net_name_notmanaged}`"is"`print_green "present"`"with VLAN ID"`print_blue ${native_net_VLAN_ID_notmanaged}`". Will reuse it..."`print_red "Check its settings."`
fi

# ISCSI network (121)
# need to add some more checks around the acli commands to catch errors
acli net.list | grep ${iscsi_net_name} 2>&1 > /dev/null
if [ $? -eq 1 ]
then
 echo `print_blue ${iscsi_net_name}`"is"`print_red "missing"`". Creating it with VLAN ID"`print_blue ${iscsi_net_VLAN_ID}`
 acli net.create ${iscsi_net_name} vlan=${iscsi_net_VLAN_ID} ip_config=${iscsi_net_ip_config} virtual_switch=${virtual_switch}
 acli net.add_dhcp_pool ${iscsi_net_name} start=${iscsi_net_pool_start_ip} end=${iscsi_net_pool_end_ip} 
 acli net.update_dhcp_dns ${iscsi_net_name} domains=${iscsi_net_domain} servers=${iscsi_net_dns_server}
 echo "  "`print_green "[Done]"`
else
 echo `print_blue ${iscsi_net_name}`"is"`print_green "present"`"with VLAN ID"`print_blue ${iscsi_net_VLAN_ID}`". Will reuse it..."`print_red "Check its settings."`
fi

# ================================================================== 
# Accept EULA:
# ================================================================== 
accept_eula=`curl -sk -H 'Content-Type: application/json' -d '{ "username": "Student", "companyName": "Nutanix", "jobTitle": "Student"}' -u admin:$ssh_password -X POST https://127.0.0.1:9440/PrismGateway/services/rest/v1/eulas/accept`
echo $accept_eula | grep true 2>&1 > /dev/null
if [ $? -eq 1 ] ; then echo "Could not accept EULA, may have already been accepted. The message we received was: "`print_blue "$accept_eula"`". This can be ignored and done manually." ; else echo "EULA"`print_green "successfully"`"accpted.";  fi

# ================================================================== 
# Disable Pulse:
# ================================================================== 
disable_pulse=`curl -sk -H 'Content-Type: application/json' -d '{ "emailContactList": null, "enable": "false", "verbosityType": null, "enableDefaultNutanixEmail": "false", "defaultNutanixEmail": null, "nosVersion": null, "isPulsePromptNeeded": "false", "remindLater": null}' -u admin:$ssh_password -X PUT https://127.0.0.1:9440/PrismGateway/services/rest/v1/pulse`
echo $disable_pulse | grep ALL 2>&1 > /dev/null
if [ $? -eq 1 ] ; then echo "Could not disable pulse, it may have already been disabled. The message we received was: "`print_blue "$disable_pulse"`". This can be ignored and done manually" ; else echo "Pulse"`print_green "successfully"`"disabled.";  fi

# ================================================================== 
# Alert Configuration: make sure no mails are sent to Nutanix
# ================================================================== 
alert_config=`curl -sk -H 'Content-Type: application/json' -d '{ "enable": false, "enableDefaultNutanixEmail": false }' -u admin:$ssh_password -X PUT https://127.0.0.1:9440/PrismGateway/services/rest/v1/alerts/configuration`
echo $alert_config | grep ALL 2>&1 > /dev/null
if [ $? -eq 1 ] ; then echo "Could disable pulse, may have already been accepted. The message we received was: "`print_blue "$alert_config"` ; else echo "Pulse"`print_green "successfully"`"disabled." ; fi

# ================================================================== 
# Set cluster name in the Prism UI (works for PC as well! - at least 2022.6.0.1)
# ================================================================== 
title_set=`curl -sk -H 'Content-Type: application/json' -d '{ "username": "system_data", "key": "product_title", "type": "CUSTOM_LOGIN_SCREEN", "value": "'$cluster_name' Prism", "identifier": null, "updatedByConfig": false }' -u admin:$ssh_password -X PUT https://127.0.0.1:9440/PrismGateway/services/rest/v1/application/system_data?type=custom_login_screen`
echo $title_set | grep -i $cluster_name 2>&1 > /dev/null
if [ $? -eq 1 ] ; then echo "Could not set login title, may have already been set. The message we received was: "`print_blue "$title_set"`". This can be ignored and done manually." ; else echo "Title"`print_green "successfully"`"set.";  fi

# ================================================================== 
# Set UI dark theme;
# ================================================================== 
# may need to experiment with PUT and POST values on initial or subsequent runs. initial should be POST, but may work with PUT
theme_set=`curl -sk -H 'Content-Type: application/json' -d '{"type":"UI_CONFIG","key":"theme","value":"dark"}' -u admin:$ssh_password -X PUT https://127.0.0.1:9440/PrismGateway/services/rest/v1/application/user_data`
echo $theme_set | grep -i dark 2>&1 > /dev/null
if [ $? -eq 1 ] ; then echo "Could not set dark theme, may have already been set. The message we received was: "`print_blue "$theme_set"`". This can be ignored and done manually." ; else echo "Title"`print_green "successfully"`"set.";  fi

# ================================================================== 
# ADD PS1 variable with clustername in it to all nodes
# ================================================================== 
grep PS1 /etc/profile 2>&1 >> /dev/null
if [ $? -eq 1 ] ; then
 echo `print_yellow "[Adding]"` "PS1 prompt variable to /etc/profile with RED clustername on all CVMs ..."
 # 2021-02-22 17:10 CET need to add double \\\\ at the end of the PS1 variable to ensure $ changes to # when switching to root with sudo -i
 for cvm in `/usr/local/nutanix/cluster/bin/svmips` ; do ssh $cvm "echo export PS1='\"\u@\$DISPLAYNAME:\$IP:\[\033[36m\] ($cluster_name)\[\033[m\] \w\\\\$ \"' | sudo tee -a /etc/profile" ; done
else
 echo "PS1 prompt variable with clustername already present at least on current prism leader ..."`print_yellow "Skipping..."`
fi
echo `print_green "[Done]"`

# ================================================================== 
# Setup the br0-up on the hosts with the 10G NICs only
# ================================================================== 
# The below seems to work even if only one of the 10g interfaces has link status active (is cabled)
echo `print yellow "[Disabling]"`"virtual switch configuration..."
echo yes | acli net.disable_virtual_switch 
#TODO Add a check and exit condition if acli fails to disable vs0
echo `print_yellow "[Setting up]"`"bonds to only contain 10g interfaces..."
for cvm in `/usr/local/nutanix/cluster/bin/svmips` ; do ssh $cvm "/usr/local/nutanix/cluster/bin/manage_ovs --interfaces 10g --bridge_name br0 --bond_name br0-up --bond_mode active-backup update_uplinks" ; done
echo `print_green "[Done]"`
# just for verification
echo `print_green "[Showing]"`"interfaces in all bonds and bridges..."
for cvm in `/usr/local/nutanix/cluster/bin/svmips` ; do ssh $cvm "/usr/local/nutanix/cluster/bin/manage_ovs show_uplinks" ; done
echo `print_green "[Done]"`

echo `print yellow "[Migrating]"`"br0 to virtual switch configuration with name vs0..."
acli net.migrate_br_to_virtual_switch br0 vs_name=vs0
#TODO Add a check and exit condition if acli fails to enable vs0

# ==================================================================
# Download different components to the cluster or a temp location on a CVM:
# ==================================================================
if [ -f $dw_path/${pc_version}.json ] ; then
  echo "PC metadata file exists, hence,"`print_red "assuming"`"download of all components was successful before."
else
  echo "PC metadata file does not exist, proceeding to download bits to temp location."
  echo `print_green "[Startring]"`"download of AOS $aos_version, Files $afs_version and PC $pc_version to $dw_path on current prism leader CVM ..."
  wget -O $dw_path/${aos_version}.tar.gz -o $dw_path/${aos_version}_dw.log $aos_bin_url 2>&1 >> /dev/null &
  wget -O $dw_path/${afs_version}.qcow2 -o $dw_path/${afs_version}_dw.log $afs_bin_url 2>&1 >> /dev/null &
  wget -O $dw_path/${pc_version}.tar -o $dw_path/${pc_version}_dw.log $pc_bin_url 2>&1 >> /dev/null &

  wget -O $dw_path/${aos_version}.json -o $dw_path/${aos_version}_meta_dw.log $aos_meta_url 2>&1 >> /dev/null
  if [ $? -gt 0 ] ; then echo `print_red "[Failed]"` "to download AOS metadata. Exiting (241) ..." ; exit 241 ; else echo `print_green "[Downloaded]"` " AOS metadata";  fi

  wget -O $dw_path/${afs_version}.json -o $dw_path/${afs_version}_meta_dw.log $afs_meta_url 2>&1 >> /dev/null
  if [ $? -gt 0 ] ; then echo `print_red "[Failed]"` "to download Files metadata. Exiting (242) ..." ; exit 242 ; else echo `print_green "[Downloaded]"` " Files metadata";  fi

  wget -O $dw_path/${pc_version}.json -o $dw_path/${pc_version}_meta_dw.log $pc_meta_url 2>&1 >> /dev/null
  if [ $? -gt 0 ] ; then echo `print_red "[Failed]"` "to download Prism Central metadata. Exiting (243) ..." ; exit 243 ; else echo `print_green "[Downloaded]"` " Prism Central metadata"; fi
fi


#monitoring downloads
while [[ ! `true` ]]
do
  echo `print_time YELLOW`
  aos_dw_percent=$(grep "\%" $dw_path/${aos_version}_dw.log | tail -n1 | awk '{ if ( NF == 9 ) {print $(NF-2)} else {print $(NF-1)} }')
  echo `print_green "[Downloading]"` "AOS $aos_version ..." `print_blue ${aos_dw_percent}`

  afs_dw_percent=$(grep "\%" $dw_path/${afs_version}_dw.log | tail -n1 | awk '{ if ( NF == 9 ) {print $(NF-2)} else {print $(NF-1)} }')
  echo `print_green "[Downloading]"` "Files $afs_version ..." `print_blue ${afs_dw_percent}`

  pc_dw_percent=$(grep "\%" $dw_path/${pc_version}_dw.log | tail -n1 | awk '{ if ( NF == 9 ) {print $(NF-2)} else {print $(NF-1)} }')
  echo `print_green "[Downloading]"` "PC $pc_version ..." `print_blue ${pc_dw_percent}`

  sleep 3
  if [[ $aos_dw_percent == "100%" && $afs_dw_percent == "100%" && $pc_dw_percent == "100%" ]] ; then echo `print_green "[DONE]"` "All bits have been downloaded to the temporary location on prsim leader CVM."; break ; fi
done

echo `print_green "[Uploading]"` "AOS $aos_version to Prism ..."
ncli software upload software-type=NOS file-path=${dw_path}/${aos_version}.tar.gz meta-file-path=${dw_path}/${aos_version}.json 2>&1 > /dev/null &

echo `print_green "[Uploading]"` "Files $afs_version to Prism ..."
ncli software upload software-type=File_Server file-path=${dw_path}/${afs_version}.qcow2 meta-file-path=${dw_path}/${afs_version}.json 2>&1 > /dev/null &

echo `print_green "[Uploading]"` "PC $pc_version to Prism ..."
ncli software upload software-type=PRISM_CENTRAL_DEPLOY file-path=${dw_path}/${pc_version}.tar meta-file-path=${dw_path}/${pc_version}.json 2>&1 > /dev/null &

echo -n `print_green "[Sleeping]"`"40 seconds to allow for the ncli tasks to start..." ; sleep 40 ; echo `print_green "[DONE]"`

# monitoring upload to prism
# tasks are not yet in ergon, hence we need progress_monitor_cli
while [[ ! `true` ]]
do
  get_output=`progress_monitor_cli --fetchall 2>&1 > /tmp/progress_monitor.log`
  task_count=`cat /tmp/progress_monitor.log | egrep 'percentage_complete' | wc -l`
  all_tasks_progress=`cat /tmp/progress_monitor.log | awk '/percent/ { sum += $NF } END {print sum}'`
  echo `print_time YELLOW`
  cat /tmp/progress_monitor.log | awk '/task_tag/ { printf "Uploading " $NF " to Prism" ; next } /percent/ { print " at " $NF "%"}'

  if [[ $((all_tasks_progress/task_count)) == 100 ]] ; then echo `print_green "[DONE]"` "All bits have been uploaded to Prism"; break ; fi

  sleep 3
done


# we need a way to monitor those uploads so that we can start them in parallel instead of the way they are at the moment.
# I have asked in slack in #ergon-task-service channel, but so far 2021-09-21 11:31 CET there is no good answer:
# https://nutanix.slack.com/archives/C08QWJWJV/p1632152877011100
# Implemented now through progress_monitor_cli in a junky way, but it works. I will need to revisit this once this has been moved to ergon.
# Hopefully the normal monitor function will then work for this.

echo "If you have already ran the script once then you can ignore error messages, like this one: \"Error: Software prism_central.<some-version> already exists on the cluster.\" However, \"Error: Softwre prism_central.<some-version> not found\" means that the mentioned SW version has been removed from the portal or the repository."
echo "In case of any errors in the last three operations, please inspect prism element and the tasks there."

exit 0