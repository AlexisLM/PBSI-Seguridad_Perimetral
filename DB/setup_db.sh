#!/bin/bash

#------------------------- Configuramos la dirección IP estática
IPADDR='192.168.20.140'
NETINTERFACE='ens33'
NETMASK='255.255.255.0'
GATEWAY='192.168.20.2'
DNS="192.168.20.150 ${GATEWAY}"
DOMAIN='becarios.local'
HOSTNAME="db.${DOMAIN}"

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
chattr +i /etc/resolv.conf

#------------------------- Configuramos el nombre del host
hostnamectl set-hostname "${HOSTNAME}"
echo "${IPADDR} ${DOMAIN} ${HOSTNAME}" >> /etc/hosts

#------------------------- Instalamos servicio de DB
# Actualizamos repositorios
apt-get update

# Instalamos MariaDB
apt-get install -y mariadb-server mariadb-client
mysql_secure_installation

# Instalamos PostgreSQL
apt-get install -y postgresql-11 postgresql-client-11
su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD 'hola123.,';\""

#------------------------- Creamos DB para WordPress
mysql -u root -p"hola123.," -e \
  "CREATE DATABASE wordpress DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
mysql -u root -p"hola123.," -e \
  "GRANT ALL ON wordpress.* TO 'wordpress'@'localhost' IDENTIFIED BY 'hola123.,';"
mysql -u root -p"hola123.," -e "FLUSH PRIVILEGES;"
