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


# ==================================================================
#  local derived cluster specific variables
# ==================================================================
# Those are from the global variables file above


# ==================================================================
# create the Lnx VGs
# ==================================================================
echo `print_yellow "============================================"`
echo `print_yellow "========== Adding Linux VGs and their disks:"`

for lnx_vg in "${lnx_vgs[@]}"
do
 acli vg.list| grep $lnx_vg 2>&1 > /dev/null
 if [ $? -eq 1 ]
 then
  echo "======= Creating"`print_blue ${lnx_vg}`
  acli vg.create $lnx_vg
  acli vg.disk_create $lnx_vg create_size=$lnx_vg_size container=${ntc_ctr_name}
 else
  echo "VG"`print_blue $lnx_vg`"already exists. Continuing to the next one..."
 fi
done

# ==================================================================
# create the Windows VGs
# ==================================================================
echo `print_yellow "============================================"`
echo `print_yellow "========== Adding Windows VGs and their disks:"`

for win_vg in "${win_vgs[@]}"
do
 acli vg.list| grep $win_vg 2>&1 > /dev/null
 if [ $? -eq 1 ]
 then
  echo "======= Creating"`print_blue ${win_vg}`
  acli vg.create $win_vg
  acli vg.disk_create $win_vg create_size=$win_vg_size container=${ntc_ctr_name}
 else
  echo "VG"`print_blue $win_vg`"already exists. Continuing to the next one..."
 fi
done



# ================================================================== 
# Attaching the Windows VGs to the Windows VMs
# ================================================================== 
for i in `seq 0 $((${#ntc_windows_vms[@]}-1))`
do
 echo `print_yellow "======= Powering on ${ntc_windows_vms[$i]}"`
 acli vm.on ${ntc_windows_vms[$i]}
 echo "Sleeping 10s and waiting for ${ntc_windows_vms[i]} to come up"
 sleep 10
 vm_state=$(acli vm.get ${ntc_windows_vms[$i]} | awk '/state:/ {print $NF}')
 echo "Current state of ${ntc_windows_vms[$i]} is: $vm_state"
 acli vm.get ${ntc_windows_vms[$i]} | grep kOn
 if [ $? -eq 1 ]; then echo "Echo ${ntc_windows_vms[$i]} is not ON yet. Sleeping 15s and retrying" ; sleep 15; fi
 acli vm.get ${ntc_windows_vms[$i]} | grep kOn 2>&1 > /dev/null
 if [ $? -eq 1 ]; then echo `print_red "Failed power on VM"`"and"`print_blue "${ntc_windows_vms[$i]}"`" is still not ON. Please check its satus manually and attach its vg to it!" ; continue ; fi # proceed with the next VM and its group if the current one does not come up in time.
 vm_ip=$(ncli vm list name="${ntc_windows_vms[$i]}" | awk '/IP/ {print $NF}')
 if [ "$vm_ip" == ":" ] ; then echo "IP not yet up, sleeping 20..." ; sleep 20 ; fi
 vm_ip=$(ncli vm list name="${ntc_windows_vms[$i]}" | awk '/IP/ {print $NF}')
 # Checking if $vm_ip is empty here (no IP yet)
 if [ ":" == "$vm_ip" ] ; then echo "IP is not up yet in ncli sleeping 20 seconds";  sleep 20 ; vm_ip=$(ncli vm list name="${ntc_windows_vms[$i]}" | awk '/IP/ {print $NF}') ; fi
 if [ ":" == "$vm_ip" ] ; then echo "IP is still not up. Please check manually. Continueing to next VM";  continue ; fi
 echo `print_blue ${ntc_windows_vms[$i]}`"is in state"`print_yellow $vm_state`"with"`print_blue $vm_ip`
 echo "Attaching VG"`print_blue ${win_vgs[$i]}`"to"`print_blue $vm_ip`"for"`print_blue ${ntc_windows_vms[$i]}...`
 acli vg.attach_external ${win_vgs[$i]} initiator_network_id=$vm_ip
done