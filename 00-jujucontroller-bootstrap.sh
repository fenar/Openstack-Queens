#!/bin/bash
#Author: Fatih E. NAR
#Juju COntroller Deployment
set -eaux
obnum=`hostname | cut -c 10- -`
time juju bootstrap  --config bootstrap-timeout=2000 --to node00vm0ob${obnum}.maas --show-log v4n${obnum}-maas  maas-v4n${obnum}-controller
echo "..."
juju gui --no-browser --show-credentials
