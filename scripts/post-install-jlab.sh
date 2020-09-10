#!/usr/bin/env bash

# Puget Systems Labs
# Machine Learning Development Server Stack
# Post Install JupyterLab Configuration

# Copyright 2020 Puget Systems and D B Kinghorn
# 
# This script will;
# - check NVIDIA driver and version for GPU support
# - Install Jupyter kernels for packages selected below
# - Install JupyterLab Extensions

# Start post-install log. Will go to post-install.log
( 

#if [[ ${#@} -ne 0 ]] && [[ "${@#"--help"}" = "" ]]; then
if [[ $# -eq 0 || "$1" == "--help" || "$1" != "--run" ]]; then 
printf  '
USAGE:  sudo ./post-install-jlab.sh --run \n
EDIT this script to select kernels to be installed\n 
This script will;\n
 - Check to see if there is an NVIDIA GPU available
 - Check the driver version (should be 450 or above)
 - If the driver is missing or out of date then exit
 - If no GPU found then the script will only install CPU based kernels\n
 '
exit 0;
fi 

#############################################################################################
# These variables control what kernels get installed
# Note GPU based kernels will not be installed unless GPU and up-to-date driver is installed
#############################################################################################
declare -a gpuapps (

TensorFlow2_GPU='yes'
PyTorch_GPU='yes'

)
declare -a cpuapps (

TensorFlow2_CPU='no'
PyTorch_CPU='no'  
SciKitLearn='yes'

)
#OneAPI='yes'
#############################################################################################


#set -e
set -o errexit # exit on errors
set -o errtrace # trap on ERR in function and subshell
trap 'install-error $? $LINENO' ERR
install-error() {
  echo "Error $1 occurred on $2"
  echo "YIKS! something failed!" 
  echo "Check post-install-jlab.log" 
}

#set -x
#trap read debug

# Check for root/sudo
if [[ $(id -u) -ne 0 ]]; then
    echo "Please use sudo to run this script"
    exit 1
fi


# Script variables
SCRIPT_HOME=$(pwd)

CONDA_HOME=/opt/conda
JHUB_HOME=${CONDA_HOME}/envs/jupyterhub
JHUB_CONFIG=${JHUB_HOME}/etc/jupyterhub/jupyterhub_config.py
JUPYTER_SYS_DIR=/usr/local/share/jupyter
KERNELS_DIR=${JUPYTER_SYS_DIR}/kernels

NOTECOLOR=$(tput setaf 3)     # Yellow
SUCCESSCOLOR=$(tput setaf 2)  # Green
ERRORCOLOR=$(tput setaf 1)    # Red
RESET=$(tput sgr0)

function note()    { echo "${NOTECOLOR}${@}${RESET}"; }
function success() { echo "${SUCCESSCOLOR}${@}${RESET}";}
function error()   { echo "${ERRORCOLOR}${@}${RESET}">&2; }

note "*******************************************************"
note "Installing JupyterLab kernels and extensions $(date)"
note "*******************************************************"

note "Checking for NVIDIA GPU and Driver version"

function get_driver_version() {
     nvidia-smi | grep Driver | cut -d " " -f 3;
}

function driver-message() { 

printf -- "

Install or Update your driver and then re-run this script.

You can try the following commands to install/update your driver,

sudo add-apt-repository --yes -q ppa:graphics-drivers/ppa
sudo apt-get update
sudo apt-get install --no-install-recommends --yes -q nvidia-driver-${NVIDIA_DRIVER_VERSION}

sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF

sudo update-initramfs -u
sudo shutdown -r now
"
exit 1
}

if lspci | grep -q NVIDIA; then
    success "[OK] Found NVIDIA GPU"
    if [[ $(which nvidia-smi) ]]; then
        driver_version=$(get_driver_version)
        note "Driver Version = ${driver_version}"
        if [[ ${driver_version%%.*}+0 -lt ${NVIDIA_DRIVER_VERSION} ]]; then
            error "Your NVIDIA Driver is out of date! "
            driver-message
        else
            success "Driver is new enough..."
            USEGPU='yes'
        fi
    else
        error "[Warning] NVIDIA Driver not installed ..."
        driver-message
    fi
else
    error "[Warning] NVIDIA GPU not detected, using CPU-only Kernels..."
fi

#
# Add some extra kernels for JupyterLab
#
note "Adding extra system kernel specs for JupyterLab..."
# make sure we are in the script dir
cd ${SCRIPT_HOME}

function add_kernel() {
    # Args: "env-name" "package-name(s)" "display-name" "icon"
    ${CONDA_HOME}/bin/conda create --yes --name $1 $2
    ${CONDA_HOME}/bin/conda install --yes --name $1 ipykernel
    ${CONDA_HOME}/envs/$1/bin/python -m ipykernel install --name $1 --display-name "$3"
    if [[ -f "kernel-icons/$4" ]]; then
        cp kernel-icons/$4 $KERNELS_DIR/$1/logo-64x64.png
    fi 
}


#add_kernel "py3" "python=3" "Python 3"

if [[ USEGPU=='yes' ]]

#add_kernel "anaconda3" "anaconda -c anaconda" "Anaconda Python3" "anacondalogo.png"  
#add_kernel "tensorflow2-gpu" "tensorflow-gpu" "TensorFlow2 GPU" "tensorflow.png" 
#add_kernel "tensorflow2-cpu" "tensorflow" "TensorFlow2 CPU" "tensorflow.png" 
#add_kernel "pytorch-gpu" "pytorch torchvision -c pytorch" "PyTorch GPU" "pytorch-logo-light.png" 



exit 0
) |& tee ./post-install-jlab.log