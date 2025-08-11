# Running GPT-OSS with Ollama + Gradio on a Supercomputer (Singularity + SLURM)
This repository contains scripts to run [Ollama](https://ollama.com/) with large-scale language models such as GPT-OSS on a supercomputer, using Singularity for containerization and SLURM for job scheduling. It also provides a Gradio web interface for easy interaction with your models.

Lask week, OpenAI released GPT-OSS as a fully open-source large language model family, marking a major shift in the accessibility of cutting-edge AI. This release enables researchers, developers, and institutions to run state-of-the-art models without relying on closed APIs, opening doors for transparent experimentation, customization, and deployment at scale. The motivation for creating this repository is to provide a ready-to-use HPC workflow that takes advantage of this new freedom—allowing you to run GPT-OSS on HPC enviroments with GPU acceleration.

It demonstrates how to run and test GPT-OSS using Ollama with an individual's own account on a SLURM-managed supercomputer. Ollama provides a lightweight framework for downloading and running AI models locally, making AI deployment and management easier across different platforms, including macOS, Linux, and Windows. You can also access the Gradio UI to chat interactively with the GPT-OSS model.


## Introduction
This setup is designed for HPC environments where:
- You have access to **SLURM-managed GPU nodes** (H200, A100 etc.).
- You want to **serve large models** (e.g., `gpt-oss:120b`) efficiently using Ollama.
- You want a **browser-based interface** (Gradio) for interacting with the model.

The SLURM job script:
- Starts Ollama inside a Singularity container with **CUDA GPU acceleration**.
- Starts Gradio UI in parallel, connected to the Ollama API.
- Includes **heartbeat monitoring** and GPU utilization reports.
- Handles **port forwarding** instructions automatically.


## Requirements
- **HPC cluster** with SLURM
- **NVIDIA GPUs** (tested on H200 140GB, A100 80G)
- **CUDA 12.1+**
- **Singularity**

## KISTI Neuron GPU Cluster
Neuron is a KISTI GPU cluster system consisting of 65 nodes with 300 GPUs (40 of NVIDIA H200 GPUs, 120 of NVIDIA A100 GPUs and 140 of NVIDIA V100 GPUs). [Slurm](https://slurm.schedmd.com/) is adopted for cluster/resource management and job scheduling.

<p align="center"><img src="https://user-images.githubusercontent.com/84169368/205237254-b916eccc-e4b7-46a8-b7ba-c156e7609314.png"/></p>

## Installing Conda
Once logging in to Neuron, you will need to have either [Anaconda](https://www.anaconda.com/) or [Miniconda](https://docs.conda.io/en/latest/miniconda.html) installed on your scratch directory. Anaconda is distribution of the Python and R programming languages for scientific computing, aiming to simplify package management and deployment. Anaconda comes with +150 data science packages, whereas Miniconda, a small bootstrap version of Anaconda, comes with a handful of what's needed.

1. Check the Neuron system specification
```
[glogin01]$ cat /etc/*release*
CentOS Linux release 7.9.2009 (Core)
Derived from Red Hat Enterprise Linux 7.8 (Source)
NAME="CentOS Linux"
VERSION="7 (Core)"
ID="centos"
ID_LIKE="rhel fedora"
VERSION_ID="7"
PRETTY_NAME="CentOS Linux 7 (Core)"
ANSI_COLOR="0;31"
CPE_NAME="cpe:/o:centos:centos:7"
HOME_URL="https://www.centos.org/"
BUG_REPORT_URL="https://bugs.centos.org/"

CENTOS_MANTISBT_PROJECT="CentOS-7"
CENTOS_MANTISBT_PROJECT_VERSION="7"
REDHAT_SUPPORT_PRODUCT="centos"
REDHAT_SUPPORT_PRODUCT_VERSION="7"

CentOS Linux release 7.9.2009 (Core)
CentOS Linux release 7.9.2009 (Core)
cpe:/o:centos:centos:7
```

2. Download Miniconda. Miniconda comes with python, conda (package & environment manager), and some basic packages. Miniconda is fast to install and could be sufficient for distributed deep learning training practices. 
``` 
[glogin01]$ cd /scratch/$USER  ## Note that $USER means your user account name on Neuron
[glogin01]$ wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh --no-check-certificate
```

3. Install Miniconda. By default conda will be installed in your home directory, which has a limited disk space. You will install and create subsequent conda environments on your scratch directory. 
```
[glogin01]$ chmod 755 Miniconda3-latest-Linux-x86_64.sh
[glogin01]$ ./Miniconda3-latest-Linux-x86_64.sh

Welcome to Miniconda3 py39_4.12.0

In order to continue the installation process, please review the license
agreement.
Please, press ENTER to continue
>>>                               <======== press ENTER here
.
.
.
Do you accept the license terms? [yes|no]
[no] >>> yes                      <========= type yes here 

Miniconda3 will now be installed into this location:
/home01/qualis/miniconda3        

  - Press ENTER to confirm the location
  - Press CTRL-C to abort the installation
  - Or specify a different location below

[/home01/qualis/miniconda3] >>> /scratch/$USER/miniconda3  <======== type /scratch/$USER/miniconda3 here
PREFIX=/scratch/qualis/miniconda3
Unpacking payload ...
Collecting package metadata (current_repodata.json): done
Solving environment: done

## Package Plan ##

  environment location: /scratch/qualis/miniconda3
.
.
.
Preparing transaction: done
Executing transaction: done
installation finished.
Do you wish to update your shell profile to automatically initialize conda?
This will activate conda on startup and change the command prompt when activated.
If you'd prefer that conda's base environment not be activated on startup,
   run the following command when conda is activated:

conda config --set auto_activate_base false

You can undo this by running `conda init --reverse $SHELL`? [yes|no]
[no] >>> yes         <========== type yes here
.
.
.
no change     /scratch/qualis/miniconda3/etc/profile.d/conda.csh
modified      /home01/qualis/.bashrc

==> For changes to take effect, close and re-open your current shell. <==

Thank you for installing Miniconda3!
```

4. finalize installing Miniconda with environment variables set including conda path

```
[glogin01]$ source ~/.bashrc    # set conda path and environment variables 
[glogin01]$ conda config --set auto_activate_base false
[glogin01]$ which conda
/scratch/$USER/miniconda3/condabin/conda
[glogin01]$ conda --version
conda 23.9.0
```

## Cloning the Repository
to set up this repository on your scratch direcory.
```
[glogin01]$ cd /scratch/$USER
[glogin01]$ git clone https://github.com/hwang2006/deepseek-with-ollama-on-supercomputer.git
[glogin01]$ cd deepseek-with-ollama-on-supercomputer
```

## Installation

### Prepare Ollama Singularity image
```bash
singularity pull ollama_latest.sif docker://ollama/ollama:latest
