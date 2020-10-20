#!/bin/bash
apt install build-essential unzip libssl-dev apache2 php libapache2-mod-php php-gd libgd-dev -y
wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.4.6.tar.gz
tar xzf nagios-4.4.6.tar.gz
cd nagios-4.4.6
./configure --with-httpd-conf=/etc/apache2/sites-enabled
make all
make install-groups-users
usermod -aG nagios www-data
make install
make install-config
make install-init
make install-daemoninit
make install-commandmode
make install-webconf
a2enmod cgi auth_digest rewrite auth_form authz_groupfile session_cookie session_crypto request
htpasswd -c /usr/local/nagios/etc/htpasswd.users nagiosadmin
systemctl restart apache2 && systemctl restart nagios
chown www-data.www-data /usr/local/nagios/etc/htpasswd.users
chmod 640 /usr/local/nagios/etc/htpasswd.users
cd
wget https://nagios-plugins.org/download/nagios-plugins-2.2.1.tar.gz
tar xzf nagios-plugins-2.2.1.tar.gz
cd nagios-plugins-2.2.1
./configure --with-nagios-user=nagios --with-nagios-group=nagios
make && make install
systemctl restart nagios
wget 'https://downloads.sourceforge.net/project/nagiosgraph/nagiosgraph/1.5.2/nagiosgraph-1.5.2.tar.gz' -O nagiosgraph-1.5.2.tar.gz
# Extrayendo contenido
tar -xvf nagiosgraph-1.5.2.tar.gz
# Entrando a carpeta de NagiosGraph(Instalacion)
cd nagiosgraph-1.5.2
# Preparando respuesta automatica para mrtg
echo "mrtg mrtg/conf_mods boolean false" | debconf-set-selections
# Instalando prerequisistos para NagiosGraph
apt-get install -y whois mrtg libcgi-pm-perl librrds-perl libgd-perl libnagios-object-perl
# Variables para automatización de instalacion de nagiosgraph
export NG_PREFIX=/etc/nagiosgraph
export NG_MODIFY_NAGIOS_CONFIG=y
export NG_NAGIOS_CONFIG_FILE=/usr/local/nagios/etc/nagios.cfg
export NG_NAGIOS_COMMANDS_FILE=/usr/local/nagios/etc/objects/commands.cfg
export NG_MODIFY_APACHE_CONFIG=y
export NG_APACHE_CONFIG_DIR=/etc/apache2/sites-available
export NG_APACHE_CONFIG_FILE=nagiosgraph.conf
# Instalacion automatizada de NagiosGraph
./install.pl
# Configuracion Apache Web Server para NagiosGraph
echo "
ScriptAlias /nagiosgraph/cgi-bin "/etc/nagiosgraph/cgi"
<Directory "/etc/nagiosgraph/cgi">
    Options ExecCGI
    AllowOverride None
    Require all granted
</Directory>
Alias /nagiosgraph "/etc/nagiosgraph/share"
<Directory "/etc/nagiosgraph/share">
    Options None
    AllowOverride None
    Require all granted
</Directory>
" >/etc/apache2/sites-available/nagiosgraph.conf
# Habilitando sitio NagiosGraph
a2ensite nagiosgraph.conf
# Agregando servicio de graficación
echo "
define service {
    name            graphed-service
    action_url      /nagiosgraph/cgi-bin/show.cgi?host=\$HOSTNAME$&service=\$SERVICEDESC$' onMouseOver='showGraphPopup(this)' onMouseOut='hideGraphPopup()' rel='/nagiosgraph/cgi-bin/showgraph.cgi?host=\$HOSTNAME$&service=\$SERVICEDESC$&period=week&rrdopts=-w+450+-j
    register        0
}" >>/usr/local/nagios/etc/objects/templates.cfg
#Modificando archivo para qye grafique todos los servicios del localhost
sed -i 's/local-service/local-service,graphed-service/g' /usr/local/nagios/etc/objects/localhost.cfg
systemctl restart apache2 && systemctl restart nagios
