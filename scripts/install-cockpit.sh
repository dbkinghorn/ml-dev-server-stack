#!/usr/bin/env bash

# install

if grep -q 'bionic' /etc/os-release; then
  apt-get install --yes -t bionic-backports cockpit
else
  apt-get install --yes cockpit
fi

# add a cockpit config file

cat << EOF > /etc/cockpit/cockpit.conf
[Session]
IdleTimeout=0

EOF

# add Puget Systems Labs branding to cockpit

# add PSlabs variant id to /etc/os-release
echo "VARIANT_ID=pslabs" >> /etc/os-release
#mkdir -p /usr/share/cockpit/branding && cp -a ubuntu-PSlabs $_
cp -a ubuntu-pslabs /usr/share/cockpit/branding/


# make it update proof

# add a script to set variant id
cat << EOF > /usr/local/sbin/add-pslabs-variant_id.sh
#!/usr/bin/env bash

# This is used to tag the 1st discovered branding directory for cockpit
# i.e $(ID}${VERSION_ID}$-${VARIANT_ID}

echo "VARIANT_ID=pslabs" >> /etc/os-release

EOF

chmod 755 /usr/local/sbin/add-pslabs-variant_id.sh

# setup direvent to monitor changes to os-release
apt-get install direvent

cat << EOF > /etc/direvent.conf
# This is the configuration file for direvent. Read
# direvent.conf(5) for more information about how to
# fill this file. 

# The following block statement declares a watcher
#watcher {
#    path pathname [recursive [level]];
#    file pattern-list;
#    event  event-list;
#    command command-line;
#    user name;
#    timeout number;
#    environ env-spec;
#    option string-list;
#}

# An example of use where test.sh has:
# #!/bin/bash
# /bin/echo "Hello, this is a test of direvent" > /tmp/test.txt

watcher {
    path /usr/lib;
    file os-release;
    event attrib;
    command "/usr/local/sbin/add-pslabs-variant_id.sh";
}

EOF

systemctl enable  direvent
systemctl restart direvent


#
# Cockpit messes up if it is not using NetworkManger so lets change Ubuntu server to use it
#

# Ubuntu server 20.04  Change from netplan to NetworkManager for all interfaces

echo 'Changing netplan to use NetowrkManager on all interfaces'
# backup existing yaml file
cd /etc/netplan
cp 01-netcfg.yaml 01-netcfg.yaml.BAK

# re-write the yaml file
cat << EOF > /etc/netplan/01-netcfg.yaml
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: NetworkManager

EOF

# setup netplan for NM
netplan generate
netplan apply
# make sure NM is running
systemctl enable NetworkManager.service
systemctl restart NetworkManager.service

echo 'Done!'