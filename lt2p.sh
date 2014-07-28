#!/bin/sh
#
# voodoo-vpn.sh: Amazon EC2 user-data file for automatic configuration of a VPN
# on a Ubuntu server instance.
#
# See http://www.sarfata.org/posts/setting-up-an-amazon-vpn-server.md
#
# Copyright Thomas Sarlandie 2012
# Contributor: scisco
#
# This work is licensed under the Creative Commons Attribution-ShareAlike 3.0
# Unported License: http://creativecommons.org/licenses/by-sa/3.0/
#
# Forked from https://github.com/sarfata/voodooprivacy
#
# Forked version is located at https://github.com/scisco/l2tp_vpn_for_ubuntu
#
# This script is intended to be used as part of a larger setup process. Do NOT
# use this script alone. It misses some important setup setups. If you just need
# to setup L2TP vpn server on your system, use the original script at
# https://github.com/sarfata/voodooprivacy

# Please define your own values for those variables
IPSEC_PSK="%KEY"

# Those two variables will be found automatically
PRIVATE_IP=$(wget -q -O - http://instance-data/latest/meta-data/local-ipv4)
PUBLIC_IP=$(wget -q -O - http://instance-data/latest/meta-data/public-hostname)

apt-get install -y openswan xl2tpd

cat > /etc/ipsec.conf <<EOF
version 2.0

config setup
  dumpdir=/var/run/pluto/
  nat_traversal=yes
  virtual_private=%v4:10.0.0.0/8,%v4:192.168.0.0/16,%v4:172.16.0.0/12,%v4:25.0.0.0/8,%v6:fd00::/8,%v6:fe80::/10
  oe=off
  protostack=netkey
  nhelpers=0
  interfaces=%defaultroute

conn vpnpsk
  auto=add
  left=$PRIVATE_IP
  leftid=$PUBLIC_IP
  leftsubnet=$PRIVATE_IP/32
  leftnexthop=%defaultroute
  leftprotoport=17/1701
  rightprotoport=17/%any
  right=%any
  rightsubnetwithin=0.0.0.0/0
  forceencaps=yes
  authby=secret
  pfs=no
  type=transport
  auth=esp
  ike=3des-sha1
  phase2alg=3des-sha1
  dpddelay=30
  dpdtimeout=120
  dpdaction=clear
EOF

cat > /etc/ipsec.secrets <<EOF
$PUBLIC_IP  %any  : PSK "$IPSEC_PSK"
EOF

cat > /etc/xl2tpd/xl2tpd.conf <<EOF
[global]
port = 1701

;debug avp = yes
;debug network = yes
;debug state = yes
;debug tunnel = yes

[lns default]
ip range = 192.168.42.10-192.168.42.250
local ip = 192.168.42.1
require chap = yes
refuse pap = yes
require authentication = yes
name = l2tpd
;ppp debug = yes
pppoptfile = /etc/ppp/options.xl2tpd
length bit = yes
EOF

cat > /etc/ppp/options.xl2tpd <<EOF
ipcp-accept-local
ipcp-accept-remote
ms-dns 8.8.8.8
ms-dns 8.8.4.4
noccp
auth
crtscts
idle 1800
mtu 1280
mru 1280
lock
connect-delay 5000
EOF

/etc/init.d/ipsec restart
/etc/init.d/xl2tpd restart
