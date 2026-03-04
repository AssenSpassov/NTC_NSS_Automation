#!/bin/bash

# author: Assen Spassov (as@nutanix.com)
# this file is meant to be copied over and executed on a CVM

# ================================================================== 
# ================================================================== 
# ================================================================== 
# this is to be populated as per https://confluence.eng.nutanix.com:8443/pages/viewpage.action?pageId=171302354
# ================================================================== 
# ================================================================== 
# ================================================================== 

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
# initializing global variables
# ================================================================== 
if [ -d ./payload ] 
then
  if [ -f ./payload/zzz-functions.sh.conf ] && [ -f ./payload/zzz-variables.sh.conf ]
  then
   source "./payload/zzz-functions.sh.conf" $LAPRAS_MODE
   source "./payload/zzz-variables.sh.conf" $LAPRAS_MODE
    if [ -f ./payload/TESTING_MODE.marker ]
     then
      TESTING_MODE=1
    fi
  else 
   echo "Failed to import formatting functions and vars in $0 with $LAPRAS_MODE! and "`pwd`" Exiting ... (255)" ; exit 255
  fi
else 
  if [ -f ./zzz-functions.sh.conf ] && [ -f ./zzz-variables.sh.conf ]
  then
   source "./zzz-functions.sh.conf" $LAPRAS_MODE
   source "./zzz-variables.sh.conf" $LAPRAS_MODE
    if [ -f ./TESTING_MODE.marker ]
     then
      TESTING_MODE=1
    fi
  else 
   echo "Failed to import formatting functions and variables in $0 and "`pwd`" with $LAPRAS_MODE! Exiting ... (255)" ; exit 255
  fi
fi

# ================================================================== 
# tweakable variables
# ================================================================== 


# ================================================================== 
#  local derived cluster specific variables 
# ================================================================== 


# ================================================================== 
#  actual work :)
# ================================================================== 