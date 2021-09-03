#!/bin/bash
apt install libnss-ldap libpam-ldap ldap-utils;
cp /etc/nsswitch.conf /etc/nsswitch.back;
cp /etc/pam.d/common-password /etc/pam.d/common-password.back
while IFS= read -r line
do
  if echo $line | grep -lq '^passwd\|^group\|^shadow\|^gshadow' ; then
    echo $line "ldap" >> nsswitch.new;
  else
    echo $line >> nsswitch.new;
  fi
done < /etc/nsswitch.conf
cp nsswitch.new /etc/nsswitch.conf
rm nsswitch.new
while IFS= read -r line
do
  if echo $line | grep -lq 'success=1' ; then
    echo 'password [success=1 user_unknown=ignore default=die] pam_ldap.so try_Step 4 - Testingfirst_pass' >> common-password.new;
  else
    echo $line >> common-password.new;
  fi
done < /etc/pam.d/common-password
echo 'session optional pam_mkhomedir.so skel=/etc/skel umask=077' >> /etc/pam.d/common-session;
echo "Reboot machine";
