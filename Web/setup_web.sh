#!/bin/bash

#------------------------- Configuramos la dirección IP estática
IPADDR='192.168.20.120'
NETINTERFACE='ens33'
NETMASK='255.255.255.0'
GATEWAY='192.168.20.2'
DNS="192.168.20.150 ${GATEWAY}"
DOMAIN='becarios.local'
HOSTNAME="www.${DOMAIN}"

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

#------------------------- Instalamos wordpress
# Actualizamos repos
apt-get update

# Instalamos dependencias
apt-get install -y apache2 php libapache2-mod-php php-mysql php-curl php-gd \
  php-mbstring php-xml php-xmlrpc php-soap php-intl php-zip curl ed dos2unix

# Creamos VirtualHost
echo "
<VirtualHost *:80>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    ServerAdmin webmaster@localhost

    DocumentRoot /var/www/html/wordpress
    Redirect permanent / https://${DOMAIN}

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

<IfModule mod_ssl.c>
  <VirtualHost _default_:443>
    ServerName ${DOMAIN}
    ServerAlias www.${DOMAIN}
    ServerAdmin webmaster@localhost

    DocumentRoot /var/www/html/wordpress

    <Directory /var/www/wordpress/>
      AllowOverride All
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined

    SSLEngine on

    SSLCertificateFile /etc/ssl/certs/becarios.pem
    SSLCertificateKeyFile /etc/ssl/private/becarios.key

    <FilesMatch \"\.(cgi|shtml|phtml|php)$\">
        SSLOptions +StdEnvVars
    </FilesMatch>
    <Directory /usr/lib/cgi-bin>
        SSLOptions +StdEnvVars
    </Directory>
  </VirtualHost>
</IfModule>
" > /etc/apache2/sites-available/wordpress.conf

# Habilitamos sitio
a2ensite wordpress.conf

# Deshabilitamos sitio por defecto
a2dissite 000-default

# Habilitamos módulo rewrite
a2enmod rewrite

# Recargamos configuración
systemctl restart apache2

# Descargamos wordpress
cd /tmp
curl -O https://wordpress.org/latest.tar.gz
tar xzvf latest.tar.gz

# Generamos configuración por defecto
cp /tmp/wordpress/wp-config-sample.php /tmp/wordpress/wp-config.php
mkdir /tmp/wordpress/wp-content/upgrade

# Copiamos el contenido completo a su lugar correspondiente
cp -a /tmp/wordpress/. /var/www/html/wordpress

# Asignamos propietario y permisos adecuados
chown -R www-data:www-data /var/www/html/wordpress
find /var/www/html/wordpress/ -type d -exec chmod 750 {} \;
find /var/www/html/wordpress/ -type f -exec chmod 640 {} \;

# Obtenemos las sales para wordpress
salts=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/ | tr -s ' ')

# Configuramos las sales en wp-config.php
printf '%s\n' "g/put your unique phrase here/d" i "$salts" . w | \
  ed -s /var/www/html/wordpress/wp-config.php
dos2unix /var/www/html/wordpress/wp-config.php

# Cambiamos datos de conexión a la DB
sed -i "s/database_name_here/wordpress/g" /var/www/html/wordpress/wp-config.php
sed -i "s/username_here/wordpress/g" /var/www/html/wordpress/wp-config.php
sed -i "s/password_here/hola123.,/g" /var/www/html/wordpress/wp-config.php
sed -i "s/localhost/192.168.20.140/g" /var/www/html/wordpress/wp-config.php

# Añadimos la siguiente linea
echo "
define('FS_METHOD', 'direct');" >> /var/www/html/wordpress/wp-config.php
