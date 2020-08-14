#!/usr/bin/env bash

# Putet Systems Labs
# Machine Learning Development Server Stack
#
# Copyright 2020 Puget Systems and D B Kinghorn
# 
# This script will;
# - check for a compatable base OS
# - install needed extra software packages
# - Insatll and configure Cockpit
# - Set netplan to use NetworkManager for Cockpit (if not set)
# - Install and configure JupyterHub with "single-user notbook server"
#   using JupyterLab
# - Add some default kernelspecs for JupyterLab 

set -o pipefail

#set -x
#trap read debug

# Check for root/sudo
if [[ $(id -u) -ne 0 ]]; then
    echo "Please use sudo to run this script"
    exit 1
fi


SCRIPT_HOME=$(pwd)

CONDA_HOME=/opt/conda
JHUB_HOME=${CONDA_HOME}/envs/jupyterhub
JHUB_CONFIG=${JHUB_HOME}/etc/jupyterhub/jupyterhub_config.py
JUPYTER_SYS_DIR=/usr/local/share/jupyter
KERNELS_DIR=${JUPYTER_SYS_DIR}/kernels


ERRORCOLOR=$(tput setaf 1)    # Red
SUCCESSCOLOR=$(tput setaf 2)  # Green
NOTECOLOR=$(tput setaf 3)     # Yellow
RESET=$(tput sgr0)

function note()    { echo "${NOTECOLOR}${@}${RESET}"; }
function success() { echo "${SUCCESSCOLOR}${@}${RESET}";}
function error()   { echo "${ERRORCOLOR}${@}${RESET}">&2; }

note "*******************************************************"
note "Installing PSLabs-ML-Dev-Server-Stack at $(date)"
note "*******************************************************"

note "Checking OS version ..."

source /etc/os-release
if [[ $NAME == "Ubuntu" ]] && [[ ${VERSION_ID/./}+0 -ge 1804 ]]; then
    success "[OK] ${PRETTY_NAME}";
else
    error "[STOP] OS must be Ubuntu 18.04 or greater"
    exit 1
fi

# Install extra packages (may already be installed)
note "Installing extra packages -- curl openssl build-essential dkms emacs-nox"
apt-get install --yes -qq curl openssl build-essential dkms emacs-nox


#
# Install Cockpit
#
note "***********************************"
note "Installing and configuring Cockpit"
note "***********************************"

if grep -q 'bionic' /etc/os-release; then
  apt-get install --yes -qq -t bionic-backports cockpit && success "[OK] Cockpit installed" \
    || error "[Fail] Cockpit not installed"
else
  apt-get install --yes -qq cockpit && success "[OK] Cockpit installed" \
    || error "[Fail] Cockpit not installed"
fi

note "Adding cockpit config ..."

sudo tee -a /etc/cockpit/cockpit.conf << 'EOF'
[Session]
IdleTimeout=0
EOF

note "Adding Puget Systems Labs branding to cockpit..."

# add PSlabs variant id to /etc/os-release
echo "VARIANT_ID=pslabs" | sudo tee -a /etc/os-release 

cp -a ubuntu-pslabs /usr/share/cockpit/branding/

# make it update proof
# add a script to set variant id
sudo tee -a /usr/local/sbin/add-pslabs-variant_id.sh << 'EOF'
#!/usr/bin/env bash

# This is used to tag the 1st discovered branding directory for cockpit
# i.e $(ID}${VERSION_ID}$-${VARIANT_ID}

echo "VARIANT_ID=pslabs" >> /etc/os-release
EOF

chmod 744 /usr/local/sbin/add-pslabs-variant_id.sh

note "seting up direvent to monitor changes to /etc/os-release ..."
apt-get install --yes -qq direvent

sudo tee -a /etc/direvent.conf << 'EOF'
#PSL-START
watcher {
    path /usr/lib;
    file os-release;
    event attrib;
    command "/usr/local/sbin/add-pslabs-variant_id.sh";
}
#PSL-STOP
EOF

systemctl enable  direvent
systemctl restart direvent

#
# Cockpit messes up if it is not using NetworkManger so lets change Ubuntu server to use it
#
note "Checking netplan configuration ..."
note "***Cockpit needs NetworkManager for net interface control***"
if grep -q -E 'renderer.*NetworkManager' /etc/netplan/*.yaml; then
    note "[OK] NetworkManager in use"
else
    note 'Changing netplan to use NetowrkManager on all interfaces ...'
    # backup existing yaml file
    cd /etc/netplan
    note "backing up existing config yaml files..."
    for i in *.yaml; do mv "$i" "$i.pslbak"; done

    # re-write the yaml file
    sudo tee /etc/netplan/01-netcfg.yaml << 'EOF'
# This file describes the network interfaces available on your system
# For more information, see netplan(5).
network:
  version: 2
  renderer: NetworkManager
EOF

fi

# setup netplan for NM
note "Activating NetworkManager netplan..."
netplan generate
netplan apply
# make sure NM is running
note "Enabeling/starting NetworkManager service..."
systemctl enable NetworkManager.service
systemctl restart NetworkManager.service

success "[OK] Cockpit installed and configured"

#
# Install JupyterHub 
#
note "************************"
note "Installing JupyterHub"
note "************************"
#
# Install conda (globally)
#

# Add repo
note "Adding conda/miniconda repo to apt source.list.d/conda.list..."
curl -L https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc | apt-key add -
echo "deb [arch=amd64] https://repo.anaconda.com/pkgs/misc/debrepo/conda stable main" | sudo tee  /etc/apt/sources.list.d/conda.list 

# Install
note "Installing conda..."
apt-get update
apt-get install --yes -qq conda  

# Setup PATH and Environment for conda on login
note "Adding conda init script to profile.d..."
ln -s ${CONDA_HOME}/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# source the conda env for root
. /etc/profile.d/conda.sh

# Update miniconda packages
note "Updating conda, python, utilities..."
conda update --yes conda
conda update --yes python
conda update --yes --all

#
# Install JupyterHub with conda
#

# Create conda env for JupyterHub and install it
note "Creating jupyterhub env, installing jupyterhub, jupyterlab, ipywidgets..."
conda create --yes --name jupyterhub  -c conda-forge jupyterhub jupyterlab ipywidgets

# Set highest priority channel to conda-forge
# to keep conda update from downgrading to anaconda channel
# This all needs to happen in the jupyterhub env!
note "Setting jupyterhub (local) environment to use conda-forge for updates..."
conda activate jupyterhub
touch $JHUB_HOME/.condarc 
conda config --env --prepend channels conda-forge
conda config --env --set channel_priority false
# go ahead and update to mixed channels now
conda update --yes --all

#
# create and setup jupyterhub config file
#
note "Creating JupyterHub config..."
mkdir -p ${JHUB_HOME}/etc/jupyterhub
cd ${JHUB_HOME}/etc/jupyterhub
${JHUB_HOME}/bin/jupyterhub --generate-config

# set default to jupyterlab
note "Setting default spawner to JupyterLab..."
sed -i "s/#c\.Spawner\.default_url = ''/c\.Spawner\.default_url = '\/lab'/" jupyterhub_config.py

# Allow the installer Python jupyter kernel spec to be reomved
note "Allowing removal of default installer python jupyter kernelspec..."
sudo tee -a ${JHUB_HOME}/etc/jupyter/jupyter_notebook_config.py << 'EOF'
# Allow removal of the default python3 kernelspec
c.KernelSpecManager.ensure_native_kernel = False
EOF

# add SSL cert and key for using https to access hub
note "Creating SSL certificate (self-signed)..."
mkdir -p ${JHUB_HOME}/etc/jupyterhub/ssl-certs
cd ${JHUB_HOME}/etc/jupyterhub/ssl-certs

openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
   -keyout jhubssl.key -out jhubssl.crt \
   -subj "/C=US/ST=Washington/L=Auburn/O=Puget Systems/OU=Labs/CN=Puget Systems Labs Self-Signed" \
   -addext "subjectAltName=DNS:localhost,DNS:localhost,IP:127.0.0.1"

sed -i "s/#c\.JupyterHub\.ssl_cert =.*/c\.JupyterHub\.ssl_cert = '\/opt\/conda\/envs\/jupyterhub\/etc\/jupyterhub\/ssl-certs\/jhubssl.crt'/" ${JHUB_CONFIG}
sed -i "s/#c\.JupyterHub\.ssl_key =.*/c\.JupyterHub\.ssl_key = '\/opt\/conda\/envs\/jupyterhub\/etc\/jupyterhub\/ssl-certs\/jhubssl.key'/" ${JHUB_CONFIG}


#
# Use systemd to start jupyterhub
#

# Create a systemd "Unit" file for starting jupyterhub,
note "Setting up systemd jupyterhub service unit file... "
mkdir -p ${JHUB_HOME}/etc/systemd

# have to use a regular here doc to parse CONDA_HOME
cat << EOF > ${CONDA_HOME}/envs/jupyterhub/etc/systemd/jupyterhub.service 
[Unit]
Description=JupyterHub
After=syslog.target network.target

[Service]
User=root
Environment="PATH=/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:${CONDA_HOME}/envs/jupyterhub/bin"
ExecStart=${CONDA_HOME}/envs/jupyterhub/bin/jupyterhub -f ${CONDA_HOME}/envs/jupyterhub/etc/jupyterhub/jupyterhub_config.py

[Install]
WantedBy=multi-user.target
EOF

# Link to systemd dir
ln -s ${JHUB_HOME}/etc/systemd/jupyterhub.service /etc/systemd/system/jupyterhub.service

# Start jupyterhub, enable it as a service,
note "Starting JupyterHub service..."
systemctl start jupyterhub.service 
systemctl enable jupyterhub.service

#
# Add some extra kernels for JupyterLab
#
note "Adding Python 3 default kernelspec for JupyterLab..."
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

# Add some kernels by default
add_kernel "py3" "python=3" "Python 3"
#add_kernel "anaconda3" "anaconda -c anaconda" "Anaconda Python3" "anacondalogo.png"  
#add_kernel "tensorflow2-gpu" "tensorflow-gpu" "TensorFlow2 GPU" "tensorflow.png" 
#add_kernel "tensorflow2-cpu" "tensorflow" "TensorFlow2 CPU" "tensorflow.png" 
#add_kernel "pytorch-gpu" "pytorch torchvision -c pytorch" "PyTorch GPU" "pytorch-logo-light.png" 
#add_kernel "pytorch-cpu" "pytorch torchvision cpuonly -c pytorch" "PyTorch CPU" "pytorch-logo-light.png" 


#${CONDA_HOME}/bin/conda create --yes -q --name anaconda3 anaconda ipykernel
#${CONDA_HOME}/envs/anaconda3/bin/python -m ipykernel install --name 'anaconda3' --display-name "Anaconda3 All"
#cp kernel-icons/anacondalogo.png ${KERNELS_DIR}/anaconda3/logo-64x64.png

#
# remove the jupyter kernelspec for the system miniconda python3 
#
note "...Removing default installer miniconda python kernelspec ..."
echo "y" | ${JHUB_HOME}/bin/jupyter kernelspec remove python3 

#
# Add PSlabs branding to jupyterhub login page
#
note "Adding Puget Systems Labs branding to JupyterHub login page..."
# make sure we are in the script dir
cd ${SCRIPT_HOME}

cp -dR jhub-branding/puget_systems_logo_white.png ${JHUB_HOME}/share/jupyterhub/static/images/
cp -dR jhub-branding/pslabs-login.html  ${JHUB_HOME}/share/jupyterhub/templates/

cd ${JHUB_HOME}/share/jupyterhub/templates
mv login.html login.html-orig
ln -s pslabs-login.html login.html

#
# Extensions
#

# Requires a rebuild of jlab
#conda activate jupyterhub
#conda install -c conda-forge jupyterlab-git
#jupyter lab build
# will need a restart of jhub before it works right 

# hack for Ubuntu 18.04 ...sudo writes root owned config files to script runners home dir!
note "Cleaning up Ubuntu 18.04 'broken' sudo rubble from installers home dir... "
if grep -q 'bionic' /etc/os-release ; then
    $(chown -R  ${SUDO_USER}:${SUDO_USER} ${HOME}/.*)
fi

success "*****************************************"
success "INSTALL COMPLETE"
success "Admin interface is on port 9090"
success "JupyterHub login is on port 8000"
success "Add Jupyter kernels with" 
success "'sudo add-sys-jupyter-kernels.sh "
success "*****************************************"

exit 0