# Admin Guide

## Understanding the JupyterHub install configuration

### Important file/directory locations

CONDA_HOME=/opt/conda
JHUB_HOME=${CONDA_HOME}/envs/jupyterhub
JHUB_CONFIG=${JHUB_HOME}/etc/jupyterhub/jupyterhub_config.py
JUPYTER_SYS_DIR=/usr/local/share/jupyter
KERNELS_DIR=${JUPYTER_SYS_DIR}/kernels
DOCS_DIR=${JUPYTER_SYS_DIR}/docs-and-examples


curl -L https://repo.anaconda.com/pkgs/misc/gpgkeys/anaconda.asc | apt-key add -
echo "deb [arch=amd64] https://repo.anaconda.com/pkgs/misc/debrepo/conda stable main" | sudo tee  /etc/apt/sources.list.d/conda.list 

ln -s ${CONDA_HOME}/etc/profile.d/conda.sh /etc/profile.d/conda.sh


mkdir -p ${JHUB_HOME}/etc/jupyterhub
cd ${JHUB_HOME}/etc/jupyterhub
${JHUB_HOME}/bin/jupyterhub --generate-config

# set default to jupyterlab
sed -i "s/#c\.Spawner\.default_url = ''/c\.Spawner\.default_url = '\/lab'/" jupyterhub_config.py

# add SSL cert and key for using https to access hub
mkdir -p ${JHUB_HOME}/etc/jupyterhub/ssl-certs
cd ${JHUB_HOME}/etc/jupyterhub/ssl-certs

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

ln -s ${JHUB_HOME}/etc/systemd/jupyterhub.service /etc/systemd/system/jupyterhub.service

