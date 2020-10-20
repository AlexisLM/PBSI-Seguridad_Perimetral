#!/bin/bash

#------------------------- Configuramos la dirección IP estática
IPADDR='192.168.20.150'
NETINTERFACE='ens33'
NETMASK='255.255.255.0'
GATEWAY='192.168.20.2'
DNS="${IPADDR} ${GATEWAY}"
DOMAIN='becarios.local'
HOSTNAME="ns.${DOMAIN}"

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
nameserver ${IPADDR}
nameserver ${GATEWAY}" > /etc/resolv.conf
chattr +i /etc/resolv.conf

#------------------------- Configuramos el nombre del host
hostnamectl set-hostname "${HOSTNAME}"
echo "${IPADDR} ${DOMAIN} ${HOSTNAME}" >> /etc/hosts

#------------------------- Instalación y Configuración del DNS
# Actualizamos repos
apt-get update

# Instalamos bind9
apt-get install -y bind9 bind9-doc dnsutils

# Movemos archivos DNS
mv *.local* /etc/bind/

# Reiniciamos servicio
systemctl reload bind9
systemctl restart bind9
