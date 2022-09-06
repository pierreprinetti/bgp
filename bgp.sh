#!/usr/bin/env bash

set -Eeuo pipefail

declare -r \
	prefix='pprinett-bgp-' \
	server_image='Fedora-Cloud-Base-35' \
	server_flavor='ci.m1.micro' \
	external_network='provider_net_shared_3' \
	key_name='pprinett'

declare \
	security_group_id=''      \
	external_spine_port_id='' \
	patch1_network_id=''      \
	patch1_subnet_id=''       \
	patch1_spine_port_id=''   \
	patch1_leaf1_port_id=''   \
	rack1_network_id=''       \
	rack1_subnet_id=''        \
	rack1_leaf1_port_id=''    \
	leaf1_server_id=''        \
	spine_server_id=''        \
	rack1_worker_port_id=''   \
	rack1_worker_server_id=''

cleanup() {
	>&2 echo
	>&2 echo 'Starting the cleanup...'

	if [ -n "$rack1_worker_server_id" ]; then
		>&2 echo "Deleting server ${rack1_worker_server_id}"
		openstack server delete "$rack1_worker_server_id" \
			|| >&2 echo "Failed to delete server ${rack1_worker_server_id}"
	fi

	if [ -n "$rack1_worker_port_id" ]; then
		>&2 echo "Deleting port ${rack1_worker_port_id}"
		openstack port delete "$rack1_worker_port_id" \
			|| >&2 echo "Failed to delete port ${rack1_worker_port_id}"
	fi

	if [ -n "$spine_server_id" ]; then
		>&2 echo "Deleting server ${spine_server_id}"
		openstack server delete "$spine_server_id" \
			|| >&2 echo "Failed to delete server ${spine_server_id}"
	fi

	if [ -n "$leaf1_server_id" ]; then
		>&2 echo "Deleting server ${leaf1_server_id}"
		openstack server delete "$leaf1_server_id" \
			|| >&2 echo "Failed to delete server ${leaf1_server_id}"
	fi

	if [ -n "$rack1_leaf1_port_id" ]; then
		>&2 echo "Deleting port ${rack1_leaf1_port_id}"
		openstack port delete "$rack1_leaf1_port_id" \
			|| >&2 echo "Failed to delete port ${rack1_leaf1_port_id}"
	fi

	if [ -n "$rack1_network_id" ]; then
		>&2 echo "Deleting network ${rack1_network_id}"
		openstack network delete "$rack1_network_id" \
			|| >&2 echo "Failed to delete network ${rack1_network_id}"
	fi

	if [ -n "$patch1_leaf1_port_id" ]; then
		>&2 echo "Deleting port ${patch1_leaf1_port_id}"
		openstack port delete "$patch1_leaf1_port_id" \
			|| >&2 echo "Failed to delete port ${patch1_leaf1_port_id}"
	fi

	if [ -n "$patch1_spine_port_id" ]; then
		>&2 echo "Deleting port ${patch1_spine_port_id}"
		openstack port delete "$patch1_spine_port_id" \
			|| >&2 echo "Failed to delete port ${patch1_spine_port_id}"
	fi

	if [ -n "$patch1_network_id" ]; then
		>&2 echo "Deleting network ${patch1_network_id}"
		openstack network delete "$patch1_network_id" \
			|| >&2 echo "Failed to delete network ${patch1_network_id}"
	fi

	if [ -n "$external_spine_port_id" ]; then
		>&2 echo "Deleting port ${external_spine_port_id}"
		openstack port delete "$external_spine_port_id" \
			|| >&2 echo "Failed to delete port ${external_spine_port_id}"
	fi

	if [ -n "$security_group_id" ]; then
		>&2 echo "Deleting security group ${security_group_id}"
		openstack security group delete "$security_group_id" \
			|| >&2 echo "Failed to delete security group ${security_group_id}"
	fi

	>&2 echo 'Cleanup done.'
}

trap cleanup EXIT

security_group_id="$(openstack security group create -f value -c id "${prefix}secgroup")"
>&2 echo "Created security group ${security_group_id}"
openstack security group rule create --ingress --protocol icmp               --description "ping" "$security_group_id" >/dev/null
openstack security group rule create --ingress --protocol tcp  --dst-port 22 --description "SSH"  "$security_group_id" >/dev/null
>&2 echo "Created security group rules"

external_spine_port_id="$(openstack port create -f value -c id \
	--network "$external_network" \
	--security-group "$security_group_id" \
	"${prefix}external-spine-port")"
>&2 echo "Created external spine port ${external_spine_port_id}"

patch1_network_id="$(openstack network create -f value -c id "${prefix}patch1-network")"
>&2 echo "Created patch1 network ${patch1_network_id}"

patch1_subnet_id="$(openstack subnet create -f value -c id \
	--network "$patch1_network_id" \
	--subnet-range '192.168.0.0/30' \
	--no-dhcp \
	"${prefix}patch1-subnet")"
>&2 echo "Created patch1 subnet ${patch1_subnet_id}"

patch1_spine_port_id="$(openstack port create -f value -c id \
	--network "$patch1_network_id" \
	--disable-port-security \
	--fixed-ip "subnet=${patch1_subnet_id},ip-address=192.168.0.1" \
	"${prefix}patch1-spine-port")"
>&2 echo "Created patch1 spine port ${patch1_spine_port_id}"

patch1_leaf1_port_id="$(openstack port create -f value -c id \
	--network "$patch1_network_id" \
	--disable-port-security \
	--fixed-ip "subnet=${patch1_subnet_id},ip-address=192.168.0.2" \
	"${prefix}patch1-leaf1-port")"
>&2 echo "Created patch1 leaf1 port ${patch1_leaf1_port_id}"

rack1_network_id="$(openstack network create -f value -c id "${prefix}rack1-network")"
>&2 echo "Created rack1 network ${rack1_network_id}"

rack1_subnet_id="$(openstack subnet create -f value -c id \
	--network "$rack1_network_id" \
	--subnet-range '192.168.10.0/24' \
	"${prefix}rack1-subnet")"
>&2 echo "Created rack1 subnet ${rack1_subnet_id}"

rack1_leaf1_port_id="$(openstack port create -f value -c id \
	--network "$rack1_network_id" \
	--security-group "$security_group_id" \
	--fixed-ip "subnet=${rack1_subnet_id},ip-address=192.168.10.1" \
	"${prefix}rack1-leaf1-port")"
>&2 echo "Created rack1 leaf1 port ${rack1_leaf1_port_id}"

leaf1_server_id="$(openstack server create -f value -c id \
	--image "$server_image" \
	--flavor "$server_flavor" \
	--security-group "${security_group_id}" \
	--nic "port-id=${patch1_leaf1_port_id}" \
	--nic "port-id=${rack1_leaf1_port_id}" \
	--key-name "$key_name" \
	"${prefix}leaf1-server")"
>&2 echo "Created leaf1 server ${leaf1_server_id}"

spine_server_id="$(openstack server create -f value -c id \
	--image "$server_image" \
	--flavor "$server_flavor" \
	--security-group "${security_group_id}" \
	--nic "port-id=${external_spine_port_id}" \
	--nic "port-id=${patch1_spine_port_id}" \
	--key-name "$key_name" \
	"${prefix}spine-server")"
>&2 echo "Created spine server ${spine_server_id}"

rack1_worker_port_id="$(openstack port create -f value -c id \
	--network "$rack1_network_id" \
	--security-group "$security_group_id" \
	--fixed-ip "subnet=${rack1_subnet_id},ip-address=192.168.10.3" \
	"${prefix}rack1-leaf1-port")"
>&2 echo "Created rack1 worker port ${rack1_worker_port_id}"

rack1_worker_server_id="$(openstack server create -f value -c id \
	--image "$server_image" \
	--flavor "$server_flavor" \
	--security-group "${security_group_id}" \
	--nic "port-id=${rack1_worker_port_id}" \
	--key-name "$key_name" \
	"${prefix}rack1-worker-server")"
>&2 echo "Created worker server ${rack1_worker_server_id}"

>&2 echo "Infrastructure up. Press ENTER to tear down."
# shellcheck disable=SC2162,SC2034
read pause
