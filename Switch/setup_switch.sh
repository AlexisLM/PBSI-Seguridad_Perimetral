#!/bin/bash

# Instalamos utilería para bridge
apt-get install -y bridge-utils

# Creamos bridge
brctl addbr brd0

# Generamos archivo de interfaces
echo -e "\nGenerando /etc/network/interfaces..."
echo "# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).
source /etc/network/interfaces.d/*
# The loopback network interface
auto lo
iface lo inet loopback

allow-hotplug ens33

allow-hotplug ens37

auto brd0
iface brd0 inet dhcp
        bridge_ports ens33 ens37
" > /etc/network/interfaces

# Reiniciamos equipo
echo "Reiniciando equipo..."
reboot
