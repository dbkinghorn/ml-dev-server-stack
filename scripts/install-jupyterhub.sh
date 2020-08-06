#!/usr/bin/env bash


#
# Install and setup JupyterHub and JupyterLab using Conda
# Includes "extras"
# Now using conda-forge channel
#

# 
SCRIPT_HOME=$PWD

CONDA_HOME=/opt/conda
JHUB_HOME=${CONDA_HOME}/envs/jupyterhub
JHUB_CONFIG=${JHUB_HOME}/etc/jupyterhub/jupyterhub_config.py
JUPYTER_SYS_DIR=/usr/local/share/jupyter
KERNELS_DIR=${JUPYTER_SYS_DIR}/kernels
DOCS_DIR=${JUPYTER_SYS_DIR}/docs-and-examples

# Install extra packages (may already be installed)
apt-get install --yes curl openssl build-essential emacs-nox

#
# Install conda (globally)
#

# Add repo
curl -L https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc | apt-key add -
echo "deb [arch=amd64] https://repo.anaconda.com/pkgs/misc/debrepo/conda stable main" | sudo tee  /etc/apt/sources.list.d/conda.list 

# Install
apt-get update
apt-get install --yes conda

# Setup PATH and Environment for conda on login
ln -s ${CONDA_HOME}/etc/profile.d/conda.sh /etc/profile.d/conda.sh

# source the conda env for root
. /etc/profile.d/conda.sh

# Update miniconda packages
conda update --yes conda
conda update --yes python
conda update --yes --all

# Add conda-forge to top of package search
#conda config --yes --add channels conda-forge

#
# Install JupyterHub with conda
#

# Create conda env for JupyterHub and install it
conda create --yes --name jupyterhub  -c conda-forge jupyterhub jupyterlab ipywidgets nodejs=10

# Set highest priority channel to conda-forge
# to keep conda update from downgrading to anaconda channel
# This all needs to happen in the jupyterhub env!
conda activate jupyterhub
touch $JHUB_HOME/.condarc 
conda config --prepend channels conda-forge
conda config --set channel_priority false
# go ahead and update to mixed channels now
conda update --yes --all

#
# create and setup jupyterhub config file
#
mkdir -p ${JHUB_HOME}/etc/jupyterhub
cd ${JHUB_HOME}/etc/jupyterhub
${JHUB_HOME}/bin/jupyterhub --generate-config

# set default to jupyterlab
sed -i "s/#c\.Spawner\.default_url = ''/c\.Spawner\.default_url = '\/lab'/" jupyterhub_config.py

# don't show the install Python kernel spec
sed -i "s/#c\.KernelSpecManager\.ensure_native_kernel = ''/c\.KernelSpecManager\.ensure_native_kernel = False/" jupyterhub_config.py

# add SSL cert and key for using https to access hub
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
mkdir -p ${JHUB_HOME}/etc/systemd

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
systemctl start jupyterhub.service 
systemctl enable jupyterhub.service

#
# remove the jupyter kernelspec for the system miniconda python3 
#
${JHUB_HOME}/bin/jupyter kernelspec remove python3 -y

#
# Add some extra kernels for JupyterLab
#

# make sure we are in the script dir
cd ${SCRIPT_HOME}

add_kernel() {
    # Args: "env-name" "package-name(s)" "display-name" "icon"
    ${CONDA_HOME}/bin/conda create --yes --name $1 $2
    ${CONDA_HOME}/bin/conda install --yes --name $1 ipykernel
    ${CONDA_HOME}/envs/$1/bin/python -m ipykernel install --name $1 --display-name "$3"
    if [[ -f "kernel-icons/$4" ]]; then
        cp kernel-icons/$4 $KERNELS_DIR/$1/logo-64x64.png
    fi 
}

# Anaconda3
add_kernel "anaconda3" "anaconda" "Anaconda3 All" "anacondalogo.png"  
add_kernel "tensorflow2-gpu" "tensorflow-gpu" "TensorFlow2 GPU" "tensorflow.png" 
add_kernel "tensorflow2-cpu" "tensorflow" "TensorFlow2 CPU" "tensorflow.png" 
add_kernel "pytorch-gpu" "pytorch torchvision -c pytorch" "PyTorch GPU" "pytorch-logo-light.png" 


#${CONDA_HOME}/bin/conda create --yes --name anaconda3 anaconda ipykernel
#${CONDA_HOME}/envs/anaconda3/bin/python -m ipykernel install --name 'anaconda3' --display-name "Anaconda3 All"
#cp kernel-icons/anacondalogo.png ${KERNELS_DIR}/anaconda3/logo-64x64.png

# # TensorFlow 2.2 CPU
# ${CONDA_HOME}/bin/conda create --yes --name tensorflow2.2-cpu tensorflow ipykernel
# ${CONDA_HOME}/envs/tensorflow2.2-cpu/bin/python -m ipykernel install --name 'tensorflow2.2-cpu' --display-name "TensorFlow2.2 CPU"
# cp kernel-icons/tensorflow.png ${KERNELS_DIR}/tensorflow2.2-cpu/logo-64x64.png

# # PyTorch 1.5
# ${CONDA_HOME}/bin/conda create --yes --name pytorch1.5-cpu ipykernel pytorch torchvision cpuonly -c pytorch 
# ${CONDA_HOME}/envs/pytorch1.5-cpu/bin/python -m ipykernel install --name 'pytorch1.5-cpu' --display-name "PyTorch 1.5 CPU"
# cp kernel-icons/pytorch-logo-light.png ${KERNELS_DIR}/pytorch1.5-cpu/logo-64x64.png

# # TensorFlow 2.2 GPU
# ${CONDA_HOME}/bin/conda create --yes --name tensorflow2-gpu tensorflow-gpu ipykernel
# ${CONDA_HOME}/envs/tensorflow2.2-cpu/bin/python -m ipykernel install --name 'tensorflow2.2-gpu' --display-name "TensorFlow 2.2 GPU"
# cp kernel-icons/tensorflow.png ${KERNELS_DIR}/tensorflow2.2-gpu/logo-64x64.png

# # PyTorch 1.5 GPU
# ${CONDA_HOME}/bin/conda create --yes --name pytorch1.5-gpu ipykernel pytorch torchvision -c pytorch 
# ${CONDA_HOME}/envs/pytorch1.5-gpu/bin/python -m ipykernel install --name 'pytorch1.5-gpu' --display-name "PyTorch 1.5 GPU"
# cp kernel-icons/pytorch-logo-light.png ${KERNELS_DIR}/pytorch1.5-gpu/logo-64x64.png


#
# Add PSlabs branding to jupyterhub login page
#

# make sure we are in the script dir
cd ${SCRIPT_HOME}

cp jhub-branding/puget_systems_logo_white.png ${JHUB_HOME}/share/jupyterhub/static/images/
cp jhub-branding/pslabs-login.html  ${JHUB_HOME}/share/jupyterhub/templates/

cd ${JHUB_HOME}/share/jupyterhub/templates
mv login.html login.html-orig
ln -s pslabs-login.html login.html

#
# Add the docs directory and link 
#
# !! THIS DOES NOT WORK WELL!!
# It's because the DOCS_DIR is owned by root. Notebooks open fine and are usable but 
# if the user then tries to open some other file and the jlab file browser is still open to this dir
# then the user will get an error because the notebook can't be written ... confusing!... 
#mkdir ${DOCS_DIR}
#ln -s ${DOCS_DIR} /etc/skel/docs-and-examples
#cp -a ${SCRIPT_HOME}/docs/* ${DOCS_DIR}

#
# Extensions
#

# Requires a rebuild of jlab
#conda activate jupyterhub
#conda install -c conda-forge jupyterlab-git
#jupyter lab build
# will need a restart of jhub before it works right 