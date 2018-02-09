#!/bin/bash
# Author: Fatih E. Nar (fenar)
# Provision Openstack IaaS
#
set -ex

obnum=`hostname | cut -c 10- -`

PKGS=" python-keystone python-neutronclient python-novaclient python-glanceclient python-openstackclient"
dpkg -l $PKGS > /dev/null || sudo apt-get install -y $PKGS

NEUTRON_EXT_NET_DNS="172.27.$((obnum+3)).254"
NEUTRON_EXT_NET_NAME="Provider-External"
NEUTRON_EXT_SUBNET_NAME="Provider-External-Subnet"
NEUTRON_EXT_NET_GW="172.27.$((obnum+3)).254"
NEUTRON_EXT_NET_CIDR="172.27.$((obnum+2)).0/23"
NEUTRON_EXT_NET_FLOAT_RANGE_START="172.27.$((obnum+3)).150"
NEUTRON_EXT_NET_FLOAT_RANGE_END="172.27.$((obnum+3)).200"
NEUTRON_EXT_NET_PHY_NET="physnet1"
NEUTRON_EXT_NET_TYPE="flat"

NEUTRON_TENANT_NET_CIDR="192.168.$((obnum)).0/24"
NEUTRON_TENANT_NET_NAME="Tenant_Network"
NEUTRON_TENANT_SUBNET_NAME="Tenant_Subnet"


keystone=$(juju status keystone | grep keystone/0 | awk '{print $5}' )

echo "#!/bin/bash
# With the addition of Keystone we have standardized on the term **project**
# as the entity that owns the resources.
unset OS_PROJECT_ID
unset OS_PROJECT_NAME
unset OS_USER_DOMAIN_NAME
unset OS_INTERFACE
export OS_USER_DOMAIN_NAME=admin_domain
export OS_PROJECT_DOMAIN_NAME=admin_domain
export OS_USERNAME=admin
export OS_TENANT_NAME=admin
export OS_PASSWORD=openstack
export OS_REGION_NAME=RegionOne
export OS_IDENTITY_API_VERSION=3
export OS_ENDPOINT_TYPE=publicURL
export OS_AUTH_URL=${OS_AUTH_PROTOCOL:-http}://`juju run --unit keystone/0 'unit-get private-address'`:5000/v3
" > nova.rc

source nova.rc

# Tenant Network
openstack network create --internal $NEUTRON_TENANT_NET_NAME
openstack subnet create --dhcp --ip-version 4 --network $NEUTRON_TENANT_NET_NAME --subnet-range $NEUTRON_TENANT_NET_CIDR $NEUTRON_TENANT_SUBNET_NAME

#EXT NET
openstack network create --external --provider-physical-network $NEUTRON_EXT_NET_PHY_NET --provider-network-type $NEUTRON_EXT_NET_TYPE $NEUTRON_EXT_NET_NAME 
openstack subnet create --dhcp --gateway $NEUTRON_EXT_NET_GW --ip-version 4 --allocation-pool start=$NEUTRON_EXT_NET_FLOAT_RANGE_START,end=$NEUTRON_EXT_NET_FLOAT_RANGE_END --dns-nameserver $NEUTRON_EXT_NET_DNS --network $NEUTRON_EXT_NET_NAME --subnet-range $NEUTRON_EXT_NET_CIDR $NEUTRON_EXT_SUBNET_NAME

#Provider Router
openstack router create --project admin --enable external-router
openstack router set external-router --external-gateway $NEUTRON_EXT_NET_NAME --enable-snat 
openstack router add subnet external-router $NEUTRON_TENANT_SUBNET_NAME 

#Configure the default security group to allow ICMP and SSH
openstack security group create test-sec-group
openstack security group rule create --proto icmp test-sec-group
openstack security group rule create --proto tcp --dst-port 1:65535 test-sec-group
openstack security group rule create --proto udp --dst-port 1:65535 test-sec-group

#Upload a default SSH key
openstack keypair create  --public-key ~/.ssh/id_rsa.pub default

#Remove the m1.tiny as it is too small for Ubuntu.
openstack flavor create m1.small --id auto --ram 4096 --disk 30 --vcpus 2
openstack flavor create m1.medium --id auto --ram 8192 --disk 35 --vcpus 2
openstack flavor create m1.large --id auto --ram 12288 --disk 40 --vcpus 4
openstack flavor create m1.xlarge --id auto --ram 16384 --disk 45 --vcpus 4

#Modify quotas for the tenant to allow large deployments
openstack quota  set --ram 204800 --cores 200 --instances 100 admin
neutron quota-update --security-group 100 --security-group-rule 500 

#Upload images to glance
glance image-create --name=ubuntu_16.04 --visibility=public --container-format=ovf --disk-format=qcow2 <  /srv/data/xenial-server-cloudimg-amd64-disk1.img
glance image-create --name=ubuntu_14.04 --visibility=public --container-format=ovf --disk-format=qcow2 <  /srv/data/trusty-server-cloudimg-amd64-disk1.img
glance image-create --name=cirros_0.4.0 --visibility=public --container-format=ovf --disk-format=qcow2 <  /srv/data/cirros-0.4.0-x86_64-disk.img
exit

