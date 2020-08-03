#!/usr/bin/env bash

# Putet Systems Labs
# Machine Learning Development Server Stack
#
# Copyright 2020 Puget Systems and D B Kinghorn

# This script will do some sanity checks for installed software
# and compatability with the server stack setup configurations
#

datestamp=​$(date +"%Y%m%d%H%M")

ERRORCOLOR=$(tput setaf 1)    # Red
SUCCESSCOLOR=$(tput setaf 2)  # Green
NOTECOLOR=$(tput setaf 3)     # Yellow
RESET=$(tput sgr0)

function note()    { echo "${NOTECOLOR}${@}${RESET}"; }
function success() { echo "${SUCCESSCOLOR}${@}${RESET}";}
function error()   { echo "${ERRORCOLOR}${@}${RESET}">&2; }

#version_greater_equal() { printf '%s\n%s\n' "$2" "$1" | sort -V -C; }

note "Installing PSLabs-ML-Dev-Server-Stack at $(date)"

note "Checking OS version"

source /etc/os-release
if [[ $NAME == "Ubuntu" ]] && [[ ${VERSION_ID/./}+0 -ge 1804 ]]; then
    success "[OK] ${PRETTY_NAME}";
else
    error "OS must be Ubuntu 18.04 or greater"
    exit 1
fi

note "Checking for NVIDIA GPU"

[[ lspci | grep NVIDIA ]] && success "[OK] Found NVIDIA GPU" || error "[Warning] NVIDIA GPU not detected, using CPU-only install..."

if [[ $(which nvidia-smi) ]]; then 
    driver-version=$(nvidia-smi | grep Driver | cut -d " " -f 3) 
    note "Driver Version = ${driver-version}"
    if [[ ${driver-version%.*}+0 -lt 440 ]]; then
        error "Your NVIDIA Driver is out of date! ... Updating"
        #add driver update
    fi
else
    error "[Warning] NVIDIA Driver not installed" 
    # install driver
fi

#
# Install Cockpit
#

note "Installing Cockpit ..."

if grep -q 'bionic' /etc/os-release; then
  apt-get install --yes -t bionic-backports cockpit && success "[OK] Cockpit installed" \
    || error "[Fail] Cockpit not installed"
else
  apt-get install --yes cockpit && success "[OK] Cockpit installed" \
    || error "[Fail] Cockpit not installed"
fi

note "Adding cockpit config ..."

cat << EOF > /etc/cockpit/cockpit.conf
[Session]
IdleTimeout=0

EOF

note "Adding Puget Systems Labs branding to cockpit..."

# add PSlabs variant id to /etc/os-release
echo "VARIANT_ID=pslabs" >> /etc/os-release
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

note "setup direvent to monitor changes to /etc/os-release ..."
apt-get install --yes direvent

cat << EOF > /etc/direvent.conf
# See direvent.conf(5) for more information
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

note 'Changing netplan to use NetowrkManager on all interfaces ...'
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

success "[OK] Cockpit installed"

# Install JupyterHub 

note "Installing JupyterHub ..."

[[ ./install-jhub.sh ]] && success "JupyterHub Installed and Configured" || error "[Fail] JupyterHub install script failed $(exit 1)"

exit 0