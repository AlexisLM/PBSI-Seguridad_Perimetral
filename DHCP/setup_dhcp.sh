#!/bin/bash

#------------------------- Configuramos la dirección IP estática
IPADDR='192.168.20.20'
NETINTERFACE='ens33'
NETMASK='255.255.255.0'
GATEWAY='192.168.20.2'
DNS="192.168.20.150 ${GATEWAY}"
DOMAIN='becarios.local'
HOSTNAME="dhcp.${DOMAIN}"

echo -e "\nGenerando /etc/network/interfaces..."
echo "# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).
source /etc/network/interfaces.d/*
# The loopback network interface
auto lo
iface lo inet loopback
auto ${NETINTERFACE}
iface ${NETINTERFACE} inet static
        address ${IPADDR}
        netmask ${NETMASK}
        gateway ${GATEWAY}
        dns-nameservers ${DNS}
" > /etc/network/interfaces

echo "Reiniciando el servicio de red..."
systemctl restart networking

echo -e "IP ${IPADDR} establecida exitosamente!\n"

#------------------------- Configuramos el dns local
echo "domain ${DOMAIN}
search ${DOMAIN}
nameserver 192.168.20.150
nameserver ${GATEWAY}" > /etc/resolv.conf

#------------------------- Configuramos el nombre del host
hostnamectl set-hostname "${HOSTNAME}"
echo "${IPADDR} ${DOMAIN} ${HOSTNAME}" >> /etc/hosts

#------------------------- Instalamos servicio de DHCP
echo "Instalando y configurando servidor DHCP..."

# Actualizamos bdd
apt-get update

# Instalamos el paquete para el dhcp
apt-get install -y isc-dhcp-server

sed -Ei 's/^#(DHCPDv4_CONF=.+)/\1/g' /etc/default/isc-dhcp-server
sed -Ei 's/^(INTERFACESv4=)""/\1"ens33"/g' /etc/default/isc-dhcp-server

# Agregamos subred para la vpn
echo "
## SubNet vpn
subnet 192.168.20.0 netmask 255.255.255.0 {
  authoritative;
  range 192.168.20.32 192.168.20.63;
  default-lease-time 3600;
  max-lease-time 3600;
  option subnet-mask 255.255.255.0;
  option broadcast-address 192.168.20.255;
  option routers 192.168.20.1;
  option domain-name-servers 8.8.8.8;
  option domain-name \"mdp-14t\";
}
" >> /etc/dhcp/dhcpd.conf

# Habilitamos y reiniciamos servicio
echo "Habilitando servicio de DHCP..."
systemctl enable isc-dhcp-server.service
echo "Iniciando servicio de DHCP..."
systemctl restart isc-dhcp-server.service

echo "Instalación y configuración finalizada!"