#!/bin/bash

# SPDX-FileCopyrightText: Copyright (c) 2022 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: LicenseRef-NvidiaProprietary
#
# NVIDIA CORPORATION, its affiliates and licensors retain all intellectual
# property and proprietary rights in and to this material, related
# documentation and any modifications thereto. Any use, reproduction,
# disclosure or distribution of this material and related documentation
# without an express license agreement from NVIDIA CORPORATION or
# its affiliates is strictly prohibited.
#

# This is the custom power control script for the launchpad training clusters.
# It integrates NVIDIA Bright Cluster Manager power control with vSphere power control using the vCenter API.
# It should be copied to /cm/local/apps/cmd/scripts/powerscripts/vsphere-power.sh on the head nodes. 
# There is no need for this script to be in the software image since the power control commands are run from the active head node
# The follwing two parameters should be set for each cluster worker node:
# Power control                           custom                                                     
# Custom power script                     /cm/local/apps/cmd/scripts/powerscripts/vsphere-power.sh 

vcenter=$(cat /root/launchpad/.vcenter-ip)
log="/tmp/vcenter-power.log"
userprefix=$(cat /root/launchpad/.lp-prefix)
debug=true

# Base64encode of user:passwd 
creds=$(cat /root/launchpad/.vcenter-creds)

# Get a session ID:
sessionid=$(curl --insecure -s -X POST -H "Authorization: Basic $creds" https://${vcenter}/api/session | tr -d '"')

# Bright calls this power control script with two arguments. The first argument is the operation to be performed, the second is the hostname of the node to be controlled
operation=$1 # ON, OFF, RESET, STATUS
device=$2    # the node that being being power controlled (e.g., node001)

clusterindex=$(ip a s ens192 | grep ether | awk '{print $2}' | cut -f5 -d":" | awk '{print substr($0,1,2)}')

# two cases:
# 1. The node has not yet been identified; CMD_MAC is "00:00:00:00:00:00" 
#   -- use the last two digits of the hostname to build the nodeindex, which should be something like "node003"
# 2. The has been identified; CMD_MAC should be something like "4E:56:44:41:01:04"
#    -- use the value of CMD_MAC to get the nodeindex
if [ "$CMD_MAC" = "00:00:00:00:00:00" ]; then 
  # use last two digits of nodename
  nodeindex=$(echo $device | sed -E 's/.*(.{2})$/\1/' | awk '{printf "%02d\n",$0;}')
else
  # use the last two digits of CMD_MAC to get the nodeindex
  nodeindex=$(echo $CMD_MAC | cut -f6 -d":" | awk '{printf "%02d\n",$0;}')
fi

# Build the nodename from the clusterindex and nodeindex
nodename="${userprefix}-${clusterindex}-Worker-${nodeindex}" #e.g., training-02-Worker-03

if [ "$nodeindex" = 04 ]; then
    nodename="${userprefix}-${clusterindex}-GPUWorker-01" # e.g., training-02-GPUWorker-01
fi

#  get the VM needed to power control the cluster nodes using the vcenter API
vm=$(curl --insecure -s -X GET -H "vmware-api-session-id: $sessionid" https://${vcenter}/api/vcenter/vm | jq -r --arg nodename "$nodename" '.[] | select(.name==$nodename) | .vm')

if [ "$debug" = true ]; then
    echo "CMD_MAC: $CMD_MAC" >> $log 
    echo "nodeindex: $nodeindex" >> $log
    echo "clusterindex: $nodeindex" >> $log
    echo "nodename: $nodename" >> $log
    echo "vm: $vm" >> $log
fi

if [ "$operation" = ON ]; then
	#echo "ON"
	curl --insecure -s -X POST -H "vmware-api-session-id: $sessionid" https://${vcenter}/api/vcenter/vm/${vm}/power?action=start
fi

if [ "$operation" = OFF ]; then
	#echo "OFF"
	curl --insecure -s -X POST -H "vmware-api-session-id: $sessionid" https://${vcenter}/api/vcenter/vm/${vm}/power?action=stop
fi

if [ "$operation" = RESET ]; then
	echo "RESET"
	curl --insecure -s -X POST -H "vmware-api-session-id: $sessionid" https://${vcenter}/api/vcenter/vm/${vm}/power?action=reset
fi

if [ "$operation" != RESET ]; then
	
	result=$(curl --insecure -s -X GET -H "vmware-api-session-id: $sessionid" https://${vcenter}/api/vcenter/vm/${vm}/power | jq -r '.state')
    
    if [ "$debug" = true ]; then
        echo "result: $result" >> $log
    fi
	
	if [[ "$result" =~ .*ON ]]; then
		echo "ON"
	else
		echo "OFF"
	fi
fi

echo >> $log
echo "----------------------------------------------" >> $log
date >> $log 2>&1
echo "operation: $operation" >> $log
echo "device: $device" >> $log
# echo "delay: $delay" >> $log
# echo "result: $result" >> $log
echo "----------------------------------------------" >> $log
echo >> $log
