#!/bin/bash
#
# Openstack IaaS Deployment Kick-Starter
# Author:Fatih E. Nar (fenar)
#
model=`juju list-models |awk '{print $1}'|grep openstack`

if [[ ${model:0:9} == "openstack" ]]; then
        juju switch openstack
        juju deploy openstack-base-queens.yaml
else
        juju add-model openstack
        juju switch openstack
        juju deploy openstack-base-queens.yaml
fi

echo "Login to the juju-gui to see status or use juju status"
juju gui --no-browser --show-credentials


