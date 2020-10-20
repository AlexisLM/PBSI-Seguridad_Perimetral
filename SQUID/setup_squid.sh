#!/bin/bash

# Rutas
acl_ip_file="/etc/squid/allowed_ips.txt"
squid_conf_file="/etc/squid/squid.conf"

# Actualizando información de paquetes
apt-get update

# Instalando paquete principal
apt-get install -y squid

# Respaldando archivo de configuración
echo "Backing up configuration file..."
cp "${squid_conf_file}"{,.backup}

# Creando lista de ip/rangos con permiso
echo "
192.168.192.0/24
" > "${acl_ip_file}"

# Creando nueva ACL
sed -i "/^acl SSL.*/i acl allowed_ips src \"${acl_ip_file}\"\n" "${squid_conf_file}"

# Agregando regla de acceso
sed -i "/^http_access deny all.*/i http_access allow allowed_ips" "${squid_conf_file}"

# Reiniciando servicio
systemctl restart squid
