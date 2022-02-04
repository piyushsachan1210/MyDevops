#AMAZON-LINUX-2-AD-DOMAIN-JOINING-SCRIPT
#!/bin/bash
Instance_Id=`curl -l http://169.254.169.254/latest/meta-data/instance-id`
#Instance_Id= 'ec2-metadata --instance-id | cut -d " " -f 2'
echo "Instance_Id is: $Instance_Id"
hostnamectl set-hostname $Instance_Id

#NSLOOKUP-TO-AWSBFSDIRECT-CHECK
nslookup AWSBFSDIRECT.COM
yum -y install sssd realmd krb5-workstation samba-common-tools
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
cat /etc/passwd |grep /bin/bash | awk -F ':' '{print $1}' | tr '\n' ' '>file.txt
echo "AllowUsers $(cat file.txt)" >> /etc/ssh/sshd_config
fi 
#ADDNING-ZENMONITOR-GROUP-IN-EXISTING-ENTRY-TO-ALLOW-GROUP
if grep -q 'AllowGroups' /etc/ssh/sshd_config
then
/bin/sed -i '/^AllowGroups / s/$/ zengroup zengroup?awsbfsdirect.com /' /etc/ssh/sshd_config
fi
#ADDNING-ZENMONITOR-GROUP-IN-NON-EXISTING-ENTRY-TO-ALLOW-GROUP
if ! grep -q 'AllowGroups' /etc/ssh/sshd_config;
then
echo "AllowGroups zengroup zengroup?awsbfsdirect.com" >> /etc/ssh/sshd_config
fi
#ALLOWING-PASSWORD-AUTHENTICATION
sed -i "/^[^#]*PasswordAuthentication[[:space:]]no/c\PasswordAuthentication yes" /etc/ssh/sshd_config
systemctl restart sshd
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
