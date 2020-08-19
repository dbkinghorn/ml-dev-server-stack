#!/usr/bin/env bash

#
# This script completely removes Conckpit JupyterHub
# and all of their configuration files and assets
#

if [[ $1 != "really-remove" ]]; then
    echo "!Before you do this read the script and be sure you agree with it!"
    echo "Then rerun the script with"
    echo "sudo ./uninstall-all.sh really-remove"
    exit 1
fi

SCRIPT_HOME=$(pwd)

CONDA_HOME=/opt/conda
JHUB_HOME=${CONDA_HOME}/envs/jupyterhub
JHUB_CONFIG=${JHUB_HOME}/etc/jupyterhub/jupyterhub_config.py
JUPYTER_SYS_DIR=/usr/local/share/jupyter

# Remove Cockpit
systemctl stop cockpit
apt-get purge cockpit
rm -Rf /etc/cockpit
rm -Rf /usr/share/cockpit/branding/ubuntu-pslabs
rm /usr/local/sbin/add-pslabs-variant_id.sh
echo "leaving direvent enabled but removing PSLabs 'watcher' from config"
sed -i '/#PSL-START/,/#PSL-STOP/d' /etc/direvent.conf;
echo "netplan config not restored (if changed by install) see /etc/netplan to restore from '.pslback' file"

# Remove the JupyterHub service
systemctl stop jupyterhub
systemctl disable jupyterhub
rm /etc/systemd/system/jupyterhub.service
rm ${JHUB_HOME}/etc/systemd/jupyterhub.service

# Remove JupyterHub conda and jupyter system kernels
apt-get remove conda
rm /etc/apt/sources.list.d/conda.list 
rm -Rf ${CONDA_HOME}
rm /etc/profile.d/conda.sh
rm -Rf ${JUPYTER_SYS_DIR}
