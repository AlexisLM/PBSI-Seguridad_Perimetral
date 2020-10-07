#!/bin/bash
apt -y install slapd ldap-utils ldapscripts
dpkg-reconfigure slapd
mkdir -p /etc/ssl/openldap/{private,certs,newcerts}
cp /usr/lib/ssl/openssl.cnf /usr/lib/ssl/openssl.back
sed '0,/.\/demoCA/s//\/etc\/ssl\/openldap/' /usr/lib/ssl/openssl.cnf > /tmp/aux
cp /tmp/aux /usr/lib/ssl/openssl.cnf
echo "1001" > /etc/ssl/openldap/serial
touch /etc/ssl/openldap/index.txt
openssl genrsa -aes256 -out /etc/ssl/openldap/private/cakey.pem 2048
openssl rsa -in /etc/ssl/openldap/private/cakey.pem -out /etc/ssl/openldap/private/cakey.pem
openssl req -new -x509 -days 3650 -key /etc/ssl/openldap/private/cakey.pem -out /etc/ssl/openldap/certs/cacert.pem
openssl genrsa -aes256 -out /etc/ssl/openldap/private/ldapserver-key.key 2048
openssl rsa -in /etc/ssl/openldap/private/ldapserver-key.key -out /etc/ssl/openldap/private/ldapserver-key.key
openssl req -new -key /etc/ssl/openldap/private/ldapserver-key.key -out /etc/ssl/openldap/certs/ldapserver-cert.csr
openssl ca -keyfile /etc/ssl/openldap/private/cakey.pem -cert /etc/ssl/openldap/certs/cacert.pem -in /etc/ssl/openldap/certs/ldapserver-cert.csr -out /etc/ssl/openldap/certs/ldapserver-cert.crt
openssl verify -CAfile /etc/ssl/openldap/certs/cacert.pem /etc/ssl/openldap/certs/ldapserver-cert.crt
chown -R openldap: /etc/ssl/openldap/
echo 'dn: cn=config' >> /tmp/ldap-tls.ldif
echo 'changetype: modify' >> /tmp/ldap-tls.ldif
echo 'add: olcTLSCACertificateFile' >> /tmp/ldap-tls.ldif
echo 'olcTLSCACertificateFile: /etc/ssl/openldap/certs/cacert.pem' >> /tmp/ldap-tls.ldif
echo '-' >> /tmp/ldap-tls.ldif
echo 'replace: olcTLSCertificateFile' >> /tmp/ldap-tls.ldif
echo 'olcTLSCertificateFile: /etc/ssl/openldap/certs/ldapserver-cert.crt' >> /tmp/ldap-tls.ldif
echo '-' >> /tmp/ldap-tls.ldif
echo 'replace: olcTLSCertificateKeyFile' >> /tmp/ldap-tls.ldif
echo 'olcTLSCertificateKeyFile: /etc/ssl/openldap/private/ldapserver-key.key' >> /tmp/ldap-tls.ldif
sed 's/\/certs\/ca-certificates.crt/\/openldap\/certs\/cacert.pem/g' /etc/ldap/ldap.conf > /tmp/aux
cp /tmp/aux /etc/ldap/ldap.conf
ldapmodify -Y EXTERNAL -H ldapi:/// -f /tmp/ldap-tls.ldif
echo 'TLS_REQCERT allow' >> /etc/ldap/ldap.conf
systemctl restart slapd
