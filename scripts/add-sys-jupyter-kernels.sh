

# This will become the post install system jupyter kernel adder

# nvidia driver checks will go here

ERRORCOLOR=$(tput setaf 1)    # Red
SUCCESSCOLOR=$(tput setaf 2)  # Green
NOTECOLOR=$(tput setaf 3)     # Yellow
RESET=$(tput sgr0)

function note()    { echo "${NOTECOLOR}${@}${RESET}"; }
function success() { echo "${SUCCESSCOLOR}${@}${RESET}";}
function error()   { echo "${ERRORCOLOR}${@}${RESET}">&2; }

NVIDIA_DRIVER_VERSION='450'
USEGPU=''

note "Checking for NVIDIA GPU"

function add_nv_driver() {
    # Args: "driver version"
    #apt-get install -q dkms
    add-apt-repository --yes -q ppa:graphics-drivers/ppa
    apt-get update
    apt-get install --no-install-recommends --yes -q nvidia-driver-$1

    sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf << 'EOF'
blacklist nouveau
options nouveau modeset=0
EOF
    update-initramfs -u
}

function get_driver_version() {
     nvidia-smi | grep Driver | cut -d " " -f 3;
}

#function add_nv_driver() {
#    # Args: driver version 
#    sudo apt-get install --yes -q nvidia-driver-$1-server
#}

if lspci | grep -q NVIDIA; then
    success "[OK] Found NVIDIA GPU"
    USEGPU=0 # 0=true
    if [[ $(which nvidia-smi) ]]; then
        driver_version=$(get_driver_version)
        note "Driver Version = ${driver_version}"
        if [[ ${driver_version%%.*}+0 -lt ${NVIDIA_DRIVER_VERSION} ]]; then
            error "Your NVIDIA Driver is out of date! ... Updating"
            add_nv_driver ${NVIDIA_DRIVER_VERSION} && success "[OK] NVIDIA Driver Installed" \
                || error "!!Driver install failed!!"
        fi
    else
        error "[Warning] NVIDIA Driver not installed ... Installing now"
        add_nv_driver ${NVIDIA_DRIVER_VERSION} && success "[OK] NVIDIA Driver Installed" \
               || error "!!NVIDIA Driver install failed!!"
    fi
else
    error "[Warning] NVIDIA GPU not detected, using CPU-only install..."
    USEGPU=1 # 1=false
fi



#
# Add some extra kernels for JupyterLab
#
note "...Adding extra default kernelspecs for JupyterLab..."
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


#${CONDA_HOME}/bin/conda create --yes -q --name anaconda3 anaconda ipykernel
#${CONDA_HOME}/envs/anaconda3/bin/python -m ipykernel install --name 'anaconda3' --display-name "Anaconda3 All"
#cp kernel-icons/anacondalogo.png ${KERNELS_DIR}/anaconda3/logo-64x64.png
