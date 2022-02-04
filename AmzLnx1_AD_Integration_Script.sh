#AMAZON-LINUX-1-AD-DOMAIN-JOINING-SCRIPT
#!/bin/bash
#NSLOOKUP-TO-AWSBFSDIRECT-CHECK
nslookup AWSBFSDIRECT.COM
yum -y install sssd realmd krb5-workstation
#AD-ID-Connect
echo BAj#ajA%cTIVE19 | realm join -U admin@awsbfsdirect.com awsbfsdirect.com --verbose
#realm join -U admin@AWSBFSDIRECT.COM -P BAj#ajA%cTIVE19 awsbfsdirect.com --verbose
#ADDING-AND-GRANTING-REQIRED-PERMISSION-TO-ZENMONITOR-USER-IN-SUDOERS-FILE
if ! grep -q 'Cmnd_Alias ZENOSS_CMDS =' /etc/sudoers
then
tee -a /etc/sudoers  /dev/null <<EOT
Defaults:zenmonitor !requiretty
Cmnd_Alias ZENOSS_CMDS = \
    /usr/sbin/dmidecode, \
    /bin/df, \
    /bin/dmesg
EOT
fi
if ! grep -q 'Cmnd_Alias ZENOSS_LVM_CMDS =' /etc/sudoers
then
tee -a /etc/sudoers  /dev/null <<EOT
Cmnd_Alias ZENOSS_LVM_CMDS = \
    /sbin/pvs, /usr/sbin/pvs, \
    /sbin/vgs, /usr/sbin/vgs, \
    /sbin/lvs, /usr/sbin/lvs
EOT
fi
if ! grep -q 'Cmnd_Alias ZENOSS_SVC_CMDS =' /etc/sudoers
then
tee -a /etc/sudoers  /dev/null <<EOT
Cmnd_Alias ZENOSS_SVC_CMDS = \
    /sbin/initctl list, \
    /sbin/service *, /usr/sbin/service *, \
    /sbin/runlevel, \
    /bin/ls -l /etc/rc?.d/
EOT
fi
if ! grep -q 'zenmonitor@awsbfsdirect.com ALL=(ALL) NOPASSWD:' /etc/sudoers
then
tee -a /etc/sudoers  /dev/null <<EOT
zenmonitor@awsbfsdirect.com ALL=(ALL) NOPASSWD: \
    ZENOSS_CMDS, \
    ZENOSS_LVM_CMDS, \
    ZENOSS_SVC_CMDS
EOT
fi
#IF-ALLOW-USER-IS--AVAILABLE-IN-SSHD_CONFIG-THEN-IT-WILL-UPDATE
if grep -q 'AllowUsers' /etc/ssh/sshd_config
then
/bin/sed -i '/^AllowUsers / s/$/ zenmonitor zenmonitor?awsbfsdirect.com/' /etc/ssh/sshd_config
fi
#IF-ALLOW-USER-IS-NOT-AVAILABLE-IN-SSHD_CONFIG-THEN-IT-WILL-ADD
if ! grep -q 'AllowUsers' /etc/ssh/sshd_config;
then
echo "AllowUsers ec2-user zenmonitor?awsbfsdirect.com bfluser bfladmin root ssm-user" >> /etc/ssh/sshd_config
fi 
#ADDNING-ZENMONITOR-GROUP-TO-ALLOW-USER
if ! grep -q 'AllowGroups zengroup zengroup?awsbfsdirect.com' /etc/ssh/sshd_config;
then
#/bin/sed -i '/^AllowGroups / s/$/ zengroup zengroup?awsbfsdirect.com /' /etc/ssh/sshd_config
echo "AllowGroups zengroup zengroup?awsbfsdirect.com" >> /etc/ssh/sshd_config
fi
#ALLOWING-PASSWORD-AUTHENTICATION
sed -i "/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes" /etc/ssh/sshd_config
service sshd restart
#PERMITTING-USER-AND-GROUP
realm permit zenmonitor@awsbfsdirect.com
realm permit -g zengroup
#ALLOWING-ICMP-TRAFFIC-FROM-10.158.100.0/28
iptables -A INPUT -s 10.158.100.0/27 -p ICMP -j ACCEPT
#ALLOWING-ICMP-TRAFFIC-TO-10.158.100.0/28
iptables -A OUTPUT -p icmp -d 10.158.100.0/27 -m state --state NEW,ESTABLISHED,RELATED -j ACCEPT
#UPDATING-IPTABLE-CONF-FILE-FOR-PERMANANT-CHANGE
iptables-save > /etc/sysconfig/iptables
sleep 10
realm leave awsbfsdirect.com
echo BAj#ajA%cTIVE19 | realm join -U admin@awsbfsdirect.com awsbfsdirect.com --verbose
realm permit zenmonitor@awsbfsdirect.com
realm permit -g zengroup
exit
