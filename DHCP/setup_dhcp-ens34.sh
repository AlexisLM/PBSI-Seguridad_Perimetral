#!/bin/bash

IPADDR01='192.168.50.20'
IPADDR02='10.10.50.10'
IFACE01='ens33'
IFACE02='ens34'
NETMASK='255.255.255.0'
GATEWAY='192.168.50.10'
DNS="172.16.50.40"
DOMAIN='mafia.local'
HOSTNAME="dhcp.${DOMAIN}"

#------------------------- Instalamos servicio de DHCP
echo "Instalando y configurando servidor DHCP..."

# Actualizamos bdd
apt-get update

# Instalamos el paquete para el dhcp
apt-get install -y isc-dhcp-server

sed -Ei 's/^#(DHCPDv4_CONF=.+)/\1/g' /etc/default/isc-dhcp-server
sed -Ei 's/^(INTERFACESv4=)""/\1"ens34"/g' /etc/default/isc-dhcp-server

# Agregamos subred para la vpn
echo "
## Red interna
subnet 10.10.50.0 netmask 255.255.255.0 {
  authoritative;
  range 10.10.50.32 10.10.50.63;
  default-lease-time 3600;
  max-lease-time 7200;
  option subnet-mask 255.255.255.0;
  option broadcast-address 10.10.50.255;
  option routers ${IPADDR02};
  option domain-name-servers ${DNS};
  option domain-name \"${DOMAIN}\";

  host client01 {
    hardware ethernet 00:0c:29:c3:3b:f3;
    fixed-address 10.10.50.31;
  }

  host client02 {
    hardware ethernet 00:0c:29:c4:4b:f4;
    fixed-address 10.10.50.32;
  }
}
" >> /etc/dhcp/dhcpd.conf

# Habilitamos y reiniciamos servicio
echo "Habilitando servicio de DHCP..."
systemctl enable isc-dhcp-server.service
echo "Iniciando servicio de DHCP..."
systemctl restart isc-dhcp-server.service

#------------------------- Configuramos la dirección IP estática
echo -e "\nGenerando /etc/network/interfaces..."
echo "# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).
source /etc/network/interfaces.d/*
# The loopback network interface
auto lo
iface lo inet loopback

auto ${IFACE01}
iface ${IFACE01} inet static
        address ${IPADDR01}
        netmask ${NETMASK}
        gateway ${GATEWAY}
        dns-nameservers ${DNS}

auto ${IFACE02}
iface ${IFACE02} inet static
        address ${IPADDR02}
        netmask ${NETMASK}
        gateway ${GATEWAY}
        dns-nameservers ${DNS}
" > /etc/network/interfaces

echo "Reiniciando el servicio de red..."
systemctl restart networking

echo -e "IP ${IPADDR01} establecida exitosamente!\n"

#------------------------- Configuramos el dns local
echo "domain ${DOMAIN}
search ${DOMAIN}
nameserver ${DNS}
nameserver ${GATEWAY}" > /etc/resolv.conf

#------------------------- Configuramos el nombre del host
hostnamectl set-hostname "${HOSTNAME}"
echo "${IPADDR01} ${HOSTNAME}
${IPADDR02} ${HOSTNAME}" >> /etc/hosts

echo "Instalación y configuración finalizada!"

#------------------------- Configuramos el NAT
# Permitimos forward
sed -Ei 's/#(net.ipv4.ip_forward=1)/\1/g' /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1

# Política restrictiva
#iptables -P INPUT DROP
#iptables -P OUTPUT DROP
#iptables -P FORWARD DROP

# Permitir reenvío de la red interna
iptables -A FORWARD -i ens34 -j ACCEPT
iptables -A FORWARD -o ens34 -j ACCEPT

# Indicamos el reenvío a la interfaz pública
iptables -t nat -A POSTROUTING -o ens33 -j MASQUERADE

# Guardamos reglas
iptables-save > iprules.txt

# Mensaje de reinicio
echo "Reinicia el equipo (reboot) y luego ejecuta:
iptables-restore < iprules.txt"
