#!/bin/bash

# author: Assen Spassov (as@nutanix.com)
# this script is meant to ran on the management VM!

# ================================================================== 
# LAPRAS specific section
# ================================================================== 
function usage {
        echo "./$(basename $0) -h anything --> shows usage"
        echo "./$(basename $0) -L 1 --> use when executed from lapras to suppres colors"
}

# ================================================================== 
# importing variables and common functions (formatting is here)
# ================================================================== 
BASEDIR=`dirname $0`
if [ -f $BASEDIR/payload/zzz-functions.sh.conf ]
then
  source "$BASEDIR/payload/zzz-functions.sh.conf" $LAPRAS_MODE
else
  source "$BASEDIR/zzz-functions.sh.conf" $LAPRAS_MODE
fi

# list of arguments expected in the input
optstring=":L:c:p:Th"

# should be set to "-L 1" in the code if called trough Lapras
# then passed to the inheriting scripts
LAPRAS_MODE=""

# a parameter needs to be set if the autoation is to be ran with testing or production images
TESTING_MODE=0

while getopts ${optstring} arg; do
  case ${arg} in
    h)
      usage
      ;;
    T)
      TESTING_MODE=1
      echo `print_yellow 'Automation is running in testing mode (different images and config!)'` # print_yellow is not yet initialized
      touch $BASEDIR/payload/TESTING_MODE.marker
      ;;
    L)
      if [ $OPTARG -eq 1 ] ; then LAPRAS_MODE="-L 1" ; fi
      echo "paramter -L suppiled with value: ${OPTARG}"
      ;;
    c)
     clusters=`echo ${OPTARG} | tr '[:upper:]' '[:lower:]'`
     ;;
    p)
     clusters_passwords="${OPTARG}"
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

# echo "LAPRAS_MODE is $LAPRAS_MODE"

# ================================================================== 
# END LAPRAS specific section
# ================================================================== 

# the below is needed for the actual rest of the commands and variables to be
# taken into account against that folder and still used, e.g. on CVM and for tar
# accordingly
cd $BASEDIR 

sgt_clusters="adrastea metis io amalthea callisto elara leda himalia themisto lisythea pandia"
local_payload_path="./payload/"
payload_folder_name="payload/"
cvm_pkg_basename="cvm.pkg.tar.gz"
cvm_path="/home/nutanix/tmp/ntc/"
ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
scp_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
ssh_key_name="instructor-key-do-not-delete"
ssh_key_file="id_rsa.pub"

function deploy ()
{
 clusters_to_deploy=`echo $@ | tr '[:upper:]' '[:lower:]'`
 passwords=""
 print_red "Passwords need to be in the RX format or at least not contain /,\\ and special characters other than the '!' one. The following are allowed: - _ !, if you need \\ you need to enter \\\\" ; echo ""
 
 if [ -z $clusters_passwords ] 
 then 
   for cluster in $clusters_to_deploy
   do
    echo -n "Current password in config for`print_blue $cluster`is: " ; password=$(cat ${local_payload_path}afs_cluster_configs/${cluster}.json | awk '/password/ {print $NF}' | tr -d \" | tr -d \,); echo $password
    read -p "Enter the password for `print_blue $cluster` or hit ENTER to confirm: "
    if [ -z ${REPLY} ] ; then passwords+=$password ; else passwords+=${REPLY} ; fi
    passwords+=" "
    unset REPLY
   done
   echo "The passwords you selected are:"
   printf "$clusters_to_deploy\n$passwords" | column -t
   
   echo -n "Is the list correct {invalid option will abort the script} [Y/n]: " ; read confirmation
   if [ -z $confirmation ] ; then print_green "Assuming answer yes"; echo "" ; confirmation="y" ; fi
   if [ $confirmation != "y" ] ; then print_red "Aborted..."; echo "Exiting... (3)" ; exit 3 ; fi
 else
   passwords="$clusters_passwords"  
   echo "The passwords have been specified through command line and will be reused:"`print_blue $passwords`
 fi
 # WARNING: The code terminates here if anything other than "y" has been selected
 
 # ================================================================== 
 # Replace te PW in the json files used for deploying Files
 # ================================================================== 
 i=0 # clusters loop
 for cluster in $clusters_to_deploy 
 do
  pw_to_use=""
  j=0 # passwords loop
  for pw in $passwords
  do
   # if [ $j -eq $i ] ; then pw_to_use=$pw ; echo "i==j --- i = $i j = $j" ; j=$(($j+1)) ; echo "i==j j+1 = $j" ; else echo "i!=j j=$j"; j=$(($j+1)); echo "i!=j j+1=$j" ; fi
   if [ $j -eq $i ] ; then pw_to_use=$pw ; j=$(($j+1)) ; else j=$(($j+1)); fi
  done
  i=$(($i+1))
  echo "Replacing current PW string for cluster"`print_blue $cluster`"in"`print_blue ${cluster}.json`"with"`print_blue $pw_to_use`
  # The sed is tricky since it requires .* to match the string independent on what the current PW is there
  # If you want to match any string (i.e. any single character zero or more times) use:
  # sed -i 's/string-.*/string-0/g' file.txt
  echo "Old PW:"`cat ${local_payload_path}afs_cluster_configs/${cluster}.json | grep passw`
  sed -i -e "s/\t\"password\" : \".*\",/\t\"password\" : \"$pw_to_use\",/g" ${local_payload_path}afs_cluster_configs/${cluster}.json
  echo "New PW:"`cat ${local_payload_path}afs_cluster_configs/${cluster}.json | grep passw`
 done
 unset i j
 
 # ================================================================== 
 # Starting setup
 # ================================================================== 
 print_yellow "Creating local archive for all clusters..." ; echo 
 pkg_name=`date +%s`"-$cvm_pkg_basename"

 log_file=$pkg_name.txt
 date >> $log_file
 echo $clusters_to_deploy >> $log_file
 echo "" >> $log_file

 if [ -f $pkg_name ] ; then echo -n "Removing $pgk_name ..." ; rm $pkg_name ; print_green "[Done]" ; echo "" ; fi
 tar -zcvf $pkg_name ${local_payload_path}*.marker* ${local_payload_path}*.sh* ${local_payload_path}*.py* ${local_payload_path}afs_cluster_configs/ 2>&1 > /dev/null
    if [ -f $BASEDIR/payload/TESTING_MODE.marker ]
     then
      rm $BASEDIR/payload/TESTING_MODE.marker
    fi
 if [ -f $pkg_name ] ; then echo "Archive`print_blue $pkg_name``print_green 'exists now/created'`" ; else print_red "Archive`print_blue $pkg_name` not found. Exiting... (4)" ; exit 4 ; fi
 echo "==================================================================" ; echo
 
 print_yellow "Starting works on the Clusters..." ; echo ""
 for cluster in $clusters_to_deploy
 do

  # Add the public key if not yet added
  echo `print_green "[Check]"`"if SSH public key is already imported on "`print_blue $cluster`"..."
  ssh_password=`cat ${local_payload_path}afs_cluster_configs/${cluster}.json | awk '/passw/ {print $NF}'  |tr -d \" | tr -d \,`
  out=`sshpass -p "$ssh_password" ssh $ssh_opts ${cluster} ". /etc/profile ; ncli cluster list-public-keys"`
  echo $out | grep $ssh_key_name 2>&1 > /dev/null
  if [ $? -eq 0 ]
  then
    echo " Output of the key check for comparison of the public key:"`print_yellow $out`
    echo " If you are still asked for password below, please verify the private key you are using matches the above listed public key signature!"
    echo `print_green "[Check success]"`"and"`print_blue "$ssh_key_name"`"is present on"`print_blue $cluster`
  else
   echo `print_yellow [Check success]`"and"`print_blue "$ssh_key_name"`"is NOT on"`print_blue $cluster`". Adding it ..."
   sshpass -p "$ssh_password" scp $scp_opts ~/.ssh/${ssh_key_file} ${cluster}:/tmp/
   if [ $? -ne 0 ] ; then echo " Return code of scp of public key to the cluster is"`print_red $?` ; fi
   sshpass -p "$ssh_password" ssh $ssh_opts ${cluster} ". /etc/profile ; ncli cluster add-public-key name=${ssh_key_name} file-path=/tmp/${ssh_key_file}" 2>&1 > /dev/null
   if [ $? -ne 0 ] ; then echo " Return code of adding the key to the cluster through ncli is"`print_red $?` ; fi
   sshpass -p "$ssh_password" ssh $ssh_opts ${cluster} ". /etc/profile ; rm /tmp/${ssh_key_file}" 2>&1 > /dev/null
   if [ $? -ne 0 ] ; then echo " Return code of deleting the temporary public key file from cluster is "`print_red $?` ; fi
   echo " Sleeping"`print_blue "10"`"seconds to make sure the key is propagated to all CVMs. If asked for password, this needs to be increased" #otherwise it prompts for password.
   sleep 10
   echo `print_green "[SSH Key added]"`"on"`print_blue ${cluster}` ; echo
  fi

  # despite the key being added above the first ssh below still asks for password if the sleep time above is not long enough!
  echo `print_green [Delete]`"and/or"`print_green '[recreate]'``print_blue $cvm_path`"on current prism leader for"`print_blue $cluster`
  ssh $ssh_opts ${cluster} "rm -rf ${cvm_path} 2>&1 >/dev/null" 2>&1 >/dev/null
  if [ $? -eq 0 ] ; then print_green "[Deleted]" ; echo "" ; else print_red "Failed to delete the path/folder." ; echo "" ; fi
  ssh $ssh_opts ${cluster} "mkdir -p ${cvm_path} 2>&1 >/dev/null" 2>&1 >/dev/null
  if [ $? -eq 0 ] ; then print_green "[(Re)created]" ; echo "" ; else print_red "Failed to create folder." ; echo "" ; fi
  echo ""
  
  echo `print_green [Copying]``print_blue $pkg_name`"to"`print_blue $cluster`"current prism leader..."
  scp $scp_opts $pkg_name ${cluster}:${cvm_path} 2>&1 >/dev/null
  if [ $? -eq 0 ]
  then
   print_green "[Copied]" ; echo ""
  # leaving the file payload package present for debugging; TODO add info about which cluster the pkg was meant for.
  # echo `print_red "[Delete]"`"local package with name"`print_blue "$pkg_name"`
  # rm -f $pkg_name
  # ls $pkg_name 2>&1 /dev/null
  # ret=$?
  # if [ $ret -eq 2 ] ; then echo `print_green "[Deleted]"` ; else `print_red [Delete failed]``print_blue "ls $pkg_name"`"command exited with"`print_red $ret`". Try running"`print_blue "rm -f $pkg_name"` ; fi
  else
   print_red "[Copy failed]" ; echo ""
  fi
  # 2020-10-01 17:35 CET === checked and working till here!
  
  echo ""
  echo `print_green "[Extracting]"``print_blue $pkg_name`"on`print_blue $cluster` current prism leader..."
  ssh $ssh_opts $cluster tar -C ${cvm_path} -zxvf ${cvm_path}${pkg_name} 2>&1 >/dev/null
  if [ $? -eq 0 ] ; then print_green "[Extracted]" ; echo "" ; else print_red "Extract failed" ; echo "" ; fi
  echo "=================================================================="`print_time`
  # 2020-10-02 12:30 CET === checked and working

  echo ""
  print_yellow "Exucting the scripts from the payload..." ; echo
  for command in ${local_payload_path}*.sh
  do
   command="$payload_folder_name`basename $command`"
   echo "`print_green [Executing]``print_blue $command $LAPRAS_MODE` on `print_blue $cluster` current prism leader..."
   ssh $ssh_opts $cluster chmod +x ${cvm_path}$command # if it is not executable
   # echo $command
   # do not forget the . /etc/profile when executing over SSH to make sure nutanix specific commands
   # are in the path variable and can be found

   ssh $ssh_opts $cluster ". /etc/profile ; cd ${cvm_path} ; ${cvm_path}$command $LAPRAS_MODE"
   ret=$?
   if [ $ret -eq 0 ] ; then print_green "[Executed] $command" ; echo "" ; else echo `print_red "[Failed]"``print_blue "$command" $LAPRAS_MODE`"returned a non-zero code on"`print_blue $cluster` ; echo "Dropping to shell with exit code"`print_red "($ret)"`"... " ; exit $ret; fi
   echo "=================================================================="`print_time`
  done
 done
}

# ================================================================== 
# gather info which clusters need to be setup
# ================================================================== 

current_time=`print_time`
print_fgred "Starting execution $current_time" ; echo

echo -n "The following clusters are in SGT:" ; print_blue $sgt_clusters ; echo ""
if [ -z "$clusters" ]
then
 echo -n "Select which cluster you want to use (space separeted list, e.g. without the quotes 'adrastea metis io'): "; read selected_clusters
else
 selected_clusters=$clusters
fi

echo -n "You have selected: "; print_blue $selected_clusters ; echo ""

if [ -z "clusters" ]
then
 echo -n "Is the above list correct (invalid option will abort the script) [Y/n]: " ; read confirmation
else
 echo "We are in LAPRAS_MODE, running with following clusters: "`print_blue $clusters`
 confirmation="y"
fi

if [ -z $confirmation ] ; then print_green "Assuming answer yes"; echo "" ; confirmation="y" ; fi

if [ $confirmation == "y" ] || [ $confirmation == "Y" ]
then
 deploy $selected_clusters
else 
 print_red "Aborted" ; echo "You have selected to abort the execution or entered invalid option (only y and n are accepted. Exiting... (1)"
 exit 1
fi