#!/bin/bash

IPADDR='172.16.50.20'
NETINTERFACE='ens33'
NETMASK='255.255.255.0'
GATEWAY='172.16.50.5'
DNS="172.16.50.40"
DOMAIN='mafia.local'
HOSTNAME="mail.${DOMAIN}"

#------------------------- Instalamos servicio de MAIL
# Actualizamos repositorios
apt-get update

# Instalamos postfix
apt-get install -y postfix

#------------------------- Configuramos SMTP y SMTPS
#--------- Configuración de SMTP
sed -Ei "37s/(myhostname =) .+/\1 mail.mafia.local/g" /etc/postfix/main.cf
sed -i "37 a mydomain = mafia.local" /etc/postfix/main.cf
sed -Ei "44s/(mynetworks = 127\.0\.0\.0/8).+/\1 172.16.50.0\/24/g" \
  /etc/postfix/main.cf


#--------- Configuración de SMTPS
# Generamos certificados
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /etc/ssl/private/mafia.key -out /etc/ssl/certs/mafia.pem

# Configuramos certificado y llave ssl
sed -Ei "27s/(smtpd_tls_cert_file=\/etc\/ssl\/certs\/)(.+)/\1mafia.pem/g" \
  /etc/postfix/main.cf
sed -Ei "28s/(smtpd_tls_key_file=\/etc\/ssl\/private\/)(.+)/\1mafia.key/g" \
  /etc/postfix/main.cf

# Habilitamos submission (puerto 587)
sed -Ei "17,22s/#(.+)/\1/g" /etc/postfix/master.cf
sed -Ei "28s/#(.+)/\1/g" /etc/postfix/master.cf

# Habilitamos smtps (puerto 465)
sed -Ei "29,33s/#(.+)/\1/g" /etc/postfix/master.cf
sed -Ei "39s/#(.+)/\1/g" /etc/postfix/master.cf

# Configuración extra de ssl
echo "
# SSL
smtpd_tls_security_level = may
smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1
smtpd_tls_loglevel = 1
" >> /etc/postfix/main.cf

#--------- Configuración de POP3, POP3S, IMAP y IMAPS
# Instalamos dovecot con soporte para IMAP(S) y POP3(S)
apt-get install -y dovecot-core dovecot-imapd dovecot-pop3d

# Configuración de Dovecot en Postfix
echo "
# ---- Dovecot
home_mailbox = Maildir/

# SMTP-Auth settings
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname
smtpd_recipient_restrictions = permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination
smtpd_sender_restrictions = reject_unauth_destination
" >> /etc/postfix/main.cf

# Configuración de dovecot.conf
sed -Ei "30s/#(.+)/\1/g" /etc/dovecot/dovecot.conf

# Configuración de autenticación con dovecot
sed -Ei "10s/#(disable_plaintext_auth = )yes/\1no/g" \
  /etc/dovecot/conf.d/10-auth.conf
sed -Ei "100s/(.+)/\1 login/g" /etc/dovecot/conf.d/10-auth.conf

# Configuración de mail.conf
sed -Ei "30s/(mail_location = ).+/\1maildir:~\/Maildir/g" \
  /etc/dovecot/conf.d/10-mail.conf

# Configuración de master.conf
sed -Ei "107,109s/#(.+)/\1/g" /etc/dovecot/conf.d/10-master.conf
sed -Ei "108 a \ \ \ \ group = postfix" /etc/dovecot/conf.d/10-master.conf
sed -Ei "108 a \ \ \ \ user = postfix" /etc/dovecot/conf.d/10-master.conf

# Configuración ssl.conf
sed -Ei "12s/(ssl_cert = <).+/\1\/etc\/ssl\/certs\/mafia.pem/g" \
  /etc/dovecot/conf.d/10-ssl.conf
sed -Ei "13s/(ssl_key = <).+/\1\/etc\/ssl\/private\/mafia.key/g" \
  /etc/dovecot/conf.d/10-ssl.conf

# Reiniciamos los servicios
systemctl restart postfix
systemctl restart dovecot

#------------------------- Configuramos la dirección IP estática
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
nameserver ${DNS}
nameserver ${GATEWAY}" > /etc/resolv.conf
chattr +i /etc/resolv.conf

#------------------------- Configuramos el nombre del host
hostnamectl set-hostname "${HOSTNAME}"
echo "${IPADDR} ${HOSTNAME}" >> /etc/hosts