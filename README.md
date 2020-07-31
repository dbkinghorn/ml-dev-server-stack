
<h1 align=center> Machine Learning Development Server Stack <br>
 Puget Systems Labs</h1>

 <a href='https://www.pugetsystems.com/'>https://www.pugetsystems.com/</a>

<!---
![Puget Systems](puget_systems_logo_color.png)

![Logos](ml-appli-logos2.png)
-->
## Introduction:

The ML Dev Server Stack consists of these primary components,

- **Cockpit**: Web Based Server Administration [https://cockpit-project.org/](https://cockpit-project.org/)
- **Conda**: Package, dependency and environment management for any language [https://docs.conda.io/en/latest/index.html](https://docs.conda.io/en/latest/index.html)

- **JupyterHub**: ... the best way to serve Jupyter notebook for multiple users [https://jupyterhub.readthedocs.io/en/stable/index.html](https://jupyterhub.readthedocs.io/en/stable/index.html)

- **JupyterLab**: ... next-generation web-based user interface for Project Jupyter [https://jupyterlab.readthedocs.io/en/stable/](https://jupyterlab.readthedocs.io/en/stable/)

- **Ubuntu Linux 18.04 or 20.04**: as the server based OS [https://ubuntu.com/](https://ubuntu.com/)


Cockpit and conda are installed from apt repositories and JupyterHub and JupyterLab are installed via the conda package manager.

All package installation and configuration setup is done using, shell scripts, maintained in this GitHub repository. 

## Prerequisites:
The install scripts require Ubuntu Linux 18.04 or 20.04 Server or Desktop platform with a network interface and SSH server installed. “Default Server” + SSH is sufficient.  All other package installation and configuration is performed by the ML Dev Server Stack scripts.

The only *strict* hardware requirement is a system capable of running Ubuntu Linux 18.04 or 20.04 server with a network interface. That includes; Full System Hardware, Virtual Machines, Cloud instances, Docker containers, and Microsoft WSL2. However, **the stack is intended to run on a "capable" server with multiple NVIDIA GPUs**.

## Installation:

## First Steps:
