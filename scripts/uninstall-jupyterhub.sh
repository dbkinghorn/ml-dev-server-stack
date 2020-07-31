#!/usr/bin/env bash

#
# This script completely removes JupyterHub
# conda and the system /usr/local/share/juypyter dir 
#

SCRIPT_HOME=$PWD

CONDA_HOME=/opt/conda
JHUB_HOME=${CONDA_HOME}/envs/jupyterhub
JHUB_CONFIG=${JHUB_HOME}/etc/jupyterhub/jupyterhub_config.py
JUPYTER_SYS_DIR=/usr/local/jupyter

# Remove the JupyterHub service
systemctl stop jupyterhub
systemctl disable jupyterhub
#rm /etc/systemd/system/jupyterhub.service
#rm ${JHUB_HOME}/etc/systemd/jupyterhub.service

# Remove JupyterHub and conda and jupyter system kernels and docs
apt-get remove --yes conda
rm -Rf ${CONDA_HOME}
rm /etc/profile.d/conda.sh
rm -Rf /usr/local/share/jupyter
rm /etc/skel/docs-and-examples
