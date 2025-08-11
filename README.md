# Running GPT-OSS with Ollama + Gradio on a Supercomputer (SLURM + Singularity)
This repository contains scripts to run [Ollama](https://ollama.com/) with large-scale language models such as GPT-OSS on a supercomputer, using Singularity for containerization and SLURM for job scheduling. It also provides a [Gradio](https://www.gradio.app/) web interface for easy interaction with your models.

Last week, OpenAI released GPT-OSS as a fully open-source large language model family, marking a major shift in the accessibility of cutting-edge AI. This release enables researchers, developers, and institutions to run state-of-the-art models without relying on closed APIs, opening doors for transparent experimentation, customization, and deployment at scale. The motivation for creating this repository is to provide a ready-to-use HPC workflow that takes advantage of this new freedom—allowing you to run GPT-OSS on HPC environments with GPU acceleration.

It demonstrates how to run and test GPT-OSS using Ollama with an individual's own account on a SLURM-managed supercomputer. Ollama provides a lightweight framework for downloading and running AI models locally, making AI deployment and management easier across different platforms, including macOS, Linux, and Windows. You can access the models through either the Gradio UI for interactive chat or the REST API for programmatic access.

## Table of Contents
- [Introduction](#introduction)
- [Requirements](#requirements)
- [KISTI Neuron GPU Cluster](#kisti-neuron-gpu-cluster)
- [Installing Conda](#installing-conda)
- [Cloning the Repository](#cloning-the-repository)
- [Preparing Ollama Singularity Image](#preparing-ollama-singularity-image)
- [Creating a Conda Virtual Environment](#creating-a-conda-virtual-environment)
- [Running Ollama and Gradio on a Compute Node](#running-ollama-and-gradio-on-a-compute-node)
- [Connecting to the Gradio UI](#connecting-to-the-gradio-ui)
- [API Access](#api-access)

## Introduction
This setup is designed for HPC environments where:
- You have access to **SLURM-managed GPU nodes** (H200, A100 etc.).
- You want to **serve large models** (e.g., `gpt-oss:120b`) efficiently using Ollama.
- You want a **browser-based interface** (Gradio) for interacting with the model.
- You need **programmatic API access** for automation and integration.

The SLURM job script:
- Starts Ollama inside a Singularity container with **CUDA GPU acceleration**.
- Starts Gradio UI in parallel, connected to the Ollama API.
- Includes **heartbeat monitoring** and GPU utilization reports.
- Handles **port forwarding** instructions automatically.
- Provides **REST API access** for programmatic interaction.

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
conda 25.7.0
```

## Cloning the Repository
to set up this repository on your scratch directory.
```
[glogin01]$ cd /scratch/$USER
[glogin01]$ git clone https://github.com/hwang2006/gpt-oss-with-ollama-on-supercomputing.git
[glogin01]$ cd gpt-oss-with-ollama-on-supercomputer
```

## Preparing Ollama Singularity Image
```bash
[glogin01]$ singularity pull ollama_latest.sif docker://ollama/ollama:latest
INFO:    Converting OCI blobs to SIF format
INFO:    Starting build...
INFO:    Fetching OCI image...
11.1MiB / 11.1MiB [===============================================] 100 % 48.6 MiB/s 0s
1.0MiB / 1.0MiB [=================================================] 100 % 48.6 MiB/s 0s
1.0GiB / 1.0GiB [=================================================] 100 % 48.6 MiB/s 0s
28.3MiB / 28.3MiB [===============================================] 100 % 48.6 MiB/s 0s
INFO:    Extracting OCI image...
INFO:    Inserting Singularity configuration...
INFO:    Creating SIF file...
[glogin01]$ singularity exec ./ollama_latest.sif ollama --version
Warning: could not connect to a running Ollama instance
Warning: client version is 0.11.4
```

## Creating a Conda Virtual Environment
1. Create a conda virtual environment with a python version 3.11+
```
[glogin01]$ conda create -n ollama-hpc python=3.11
Retrieving notices: ...working... done
Collecting package metadata (current_repodata.json): done
Solving environment: done

## Package Plan ## 

  environment location: /scratch/qualis/miniconda3/envs/ollama-hpc

  added / updated specs:
    - python=3.11
.
.
.
Proceed ([y]/n)? y    <========== type yes

Downloading and Extracting Packages:

Preparing transaction: done
Verifying transaction: done
Executing transaction: done
#
# To activate this environment, use
#
#     $ conda activate ollama-hpc
#
# To deactivate an active environment, use
#
#     $ conda deactivate
```

2. load modules
```
[glogin01]$ module load gcc/10.2.0 cuda/12.1
```

3. Install Gradio for UI
```
[glogin01]$ conda activate ollama-hpc
(ollama-hpc) [glogin01]$ pip install gradio
Looking in indexes: https://pypi.org/simple, https://pypi.ngc.nvidia.com
Collecting gradio
  Downloading gradio-5.42.0-py3-none-any.whl.metadata (16 kB)
Collecting aiofiles<25.0,>=22.0 (from gradio)
  Downloading aiofiles-24.1.0-py3-none-any.whl.metadata (10 kB)
.
.
.
Successfully installed aiofiles-24.1.0 annotated-types-0.7.0 anyio-4.10.0 brotli-1.1.0 certifi-2025.8.3 charset_normalizer-3.4.3 click-8.2.1 fastapi-0.116.1 ffmpy-0.6.1 filelock-3.18.0 fsspec-2025.7.0 gradio-5.42.0 gradio-client-1.11.1 groovy-0.1.2 h11-0.16.0 hf-xet-1.1.7 httpcore-1.0.9 httpx-0.28.1 huggingface-hub-0.34.4 idna-3.10 jinja2-3.1.6 markdown-it-py-3.0.0 markupsafe-3.0.2 mdurl-0.1.2 numpy-2.3.2 orjson-3.11.1 packaging-25.0 pandas-2.3.1 pillow-11.3.0 pydantic-2.11.7 pydantic-core-2.33.2 pydub-0.25.1 pygments-2.19.2 python-dateutil-2.9.0.post0 python-multipart-0.0.20 pytz-2025.2 pyyaml-6.0.2 requests-2.32.4 rich-14.1.0 ruff-0.12.8 safehttpx-0.1.6 semantic-version-2.10.0 shellingham-1.5.4 six-1.17.0 sniffio-1.3.1 starlette-0.47.2 tomlkit-0.13.3 tqdm-4.67.1 typer-0.16.0 typing-extensions-4.14.1 typing-inspection-0.4.1 tzdata-2025.2 urllib3-2.5.0 uvicorn-0.35.0 websockets-15.0.1
```

## Running Ollama and Gradio on a Compute Node
This section describes how to run the Gradio UI along with launching the Ollama server on a compute node. The following Slurm script will start both servers and output a port forwarding command, which you can use to connect remotely.

### Slurm Script (ollama_gradio_run_singularity.sh)
```bash
#!/bin/bash
#SBATCH --job-name=ollama_gradio
#SBATCH --comment=pytorch
##SBATCH --partition=mig_amd_a100_4
##SBATCH --partition=gh200_1
#SBATCH --partition=eme_h200nv_8
##SBATCH --partition=amd_a100nv_8
##SBATCH --partition=cas_v100nv_8
##SBATCH --partition=cas_v100nv_4
##SBATCH --partition=cas_v100_4
##SBATCH --partition=bigmem
##SBATCH --partition=gdebug01
#SBATCH --time=48:00:00        # walltime
##SBATCH --time=12:00:00        # walltime
#SBATCH --nodes=1             # the number of nodes
#SBATCH --ntasks-per-node=1   # number of tasks per node
#SBATCH --gres=gpu:1          # number of gpus per node
#SBATCH --cpus-per-task=8     # number of cpus per task

set +e

#######################################
# Config you may tweak
#######################################
SERVER="$(hostname)"
PORT_GRADIO=7860
OLLAMA_PORT=11434
#DEFAULT_MODEL="gemma:latest"      # Preferred model (UI will auto-select & warm this)
#DEFAULT_MODEL="gpt-oss:latest"      # Preferred model (UI will auto-select & warm this)
DEFAULT_MODEL=0
#OLLAMA_CTX=4096                 # (optional) set for faster cold start on big models

WORK_DIR="/scratch/$USER/gpt-oss-with-ollama-on-supercomputing/"
OLLAMA_MODELS="/scratch/$USER/.ollama"

# Force NVIDIA path by unsetting AMD/ROCm vars
unset ROCR_VISIBLE_DEVICES

# Detect SLURM job ID or set a fallback
JOB_ID="${SLURM_JOB_ID:-none}"

if [ "$JOB_ID" = "none" ]; then
    GRADIO_LOG="${WORK_DIR}/gradio_server.log"
    OLLAMA_LOG="${WORK_DIR}/ollama_server.log"
    PORT_FWD_FILE="${WORK_DIR}/port_forwarding.txt"
else
    GRADIO_LOG="${WORK_DIR}/gradio_server_${JOB_ID}.log"
    OLLAMA_LOG="${WORK_DIR}/ollama_server_${JOB_ID}.log"
    PORT_FWD_FILE="${WORK_DIR}/port_forwarding_${JOB_ID}.txt"
fi

export XDG_CACHE_HOME="/scratch/${USER}/.gradio_cache"
export TMPDIR="/scratch/${USER}/tmp"

mkdir -p "$WORK_DIR" "$OLLAMA_MODELS" "$XDG_CACHE_HOME" "$TMPDIR"

#######################################
# Cleanup
#######################################
cleanup() {
  echo "[$(date)] Cleaning up processes..."
  [ -n "$OLLAMA_PID" ] && kill -TERM "$OLLAMA_PID" 2>/dev/null && sleep 2 && kill -9 "$OLLAMA_PID" 2>/dev/null
  [ -n "$GRADIO_PID" ] && kill -TERM "$GRADIO_PID" 2>/dev/null && sleep 2 && kill -9 "$GRADIO_PID" 2>/dev/null
  pkill -f "ollama" 2>/dev/null || true
  echo "[$(date)] Cleanup complete"
}
trap cleanup EXIT INT TERM

#######################################
# Info
#######################################
echo "========================================"
echo "Starting Ollama + Gradio"
echo "Date: $(date)"
echo "Server: $SERVER"
echo "SLURM Job ID: ${SLURM_JOB_ID}"
echo "Gradio Port: $PORT_GRADIO"
echo "Ollama Port: $OLLAMA_PORT"
echo "Default Model: $DEFAULT_MODEL"
echo "========================================"
echo "ssh -L localhost:${PORT_GRADIO}:${SERVER}:${PORT_GRADIO} -L localhost:${OLLAMA_PORT}:${SERVER}:${OLLAMA_PORT} ${USER}@neuron.ksc.re.kr" > "$PORT_FWD_FILE"

#######################################
# Env / modules
#######################################
if [ -f /etc/profile.d/modules.sh ]; then . /etc/profile.d/modules.sh; fi
module load gcc/10.2.0 cuda/12.1

# Activate conda environment
source ~/.bashrc
conda activate ollama-hpc

#######################################
# Clean stale logs / procs
#######################################
pkill -f "ollama serve" 2>/dev/null || true
pkill -f "ollama_web" 2>/dev/null || true
rm -f "$OLLAMA_LOG" "$GRADIO_LOG"

#######################################
# Start Ollama (Singularity RUN)
#######################################
echo "🚀 Starting Ollama server..."
cd "$WORK_DIR"  #make sure that ollama_latest.sif is located.:

# Safer for shared nodes: bind to localhost; tunnel as needed.
#export SINGULARITYENV_OLLAMA_HOST="127.0.0.1:${OLLAMA_PORT}"
#export SINGULARITYENV_OLLAMA_KEEP_ALIVE="10m"
#export SINGULARITYENV_OLLAMA_LLM_LIBRARY="cuda"
#export SINGULARITYENV_OLLAMA_FLASH_ATTENTION="true"

# Tune as desired:
#export SINGULARITYENV_OLLAMA_CONTEXT_LENGTH="${OLLAMA_CONTEXT_LENGTH:-4096}"
#export SINGULARITYENV_OLLAMA_NUM_PARALLEL="${OLLAMA_NUM_PARALLEL:-4}"
#export SINGULARITYENV_OLLAMA_MAX_LOADED_MODELS="${OLLAMA_MAX_LOADED_MODELS:-2}"
#export SINGULARITYENV_OLLAMA_MODELS="${OLLAMA_MODELS}"
#export SINGULARITYENV_CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"


# Launch
nohup singularity run --nv \
  --env OLLAMA_LLM_LIBRARY=cuda \
  --env OLLAMA_HOST=0.0.0.0:${OLLAMA_PORT} \
  --env OLLAMA_MODELS="$OLLAMA_MODELS" \
  --env OLLAMA_MAX_LOADED_MODELS=3 \
  --env OLLAMA_NUM_PARALLEL=6 \
  --env OLLAMA_FLASH_ATTENTION=1 \
  --env OLLAMA_KV_CACHE_TYPE=f16 \
  --env OLLAMA_GPU_OVERHEAD=209715200 \
  --env OLLAMA_KEEP_ALIVE=30m \
  --env OLLAMA_MAX_QUEUE=128 \
  --env CUDA_VISIBLE_DEVICES=0 \
  --env OLLAMA_FORCE_GPU=1 \
  --env DEFAULT_MODEL="${DEFAULT_MODEL}" \
  ./ollama_latest.sif serve > "$OLLAMA_LOG" 2>&1 &

OLLAMA_PID=$!
echo "Ollama PID: $OLLAMA_PID"

#######################################
# Wait for Ollama API
#######################################
MAX_WAIT=180
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
  if curl -s "http://localhost:${OLLAMA_PORT}/api/tags" >/dev/null; then
    echo "✅ Ollama API is up!"
    break
  fi
  COUNTER=$((COUNTER + 2))
  echo "Waiting for Ollama API... (${COUNTER}s)"
  sleep 2
done
[ $COUNTER -ge $MAX_WAIT ] && { echo "❌ Ollama API startup timeout"; tail -60 "$OLLAMA_LOG"; exit 1; }

#######################################
# Start Gradio (UI reads DEFAULT_MODEL & preloads it)
#######################################
echo "🌐 Starting Gradio web interface..."

# 🔑 critical: also export DEFAULT_MODEL to THIS shell so Python sees it
export DEFAULT_MODEL
nohup python ollama_web.py --host=0.0.0.0 --port=${PORT_GRADIO} > "$GRADIO_LOG" 2>&1 &
GRADIO_PID=$!
echo "Gradio PID: $GRADIO_PID"

#######################################
# Wait for Gradio UI
#######################################
GRADIO_URL="http://127.0.0.1:${PORT_GRADIO}/"
echo "⏳ Waiting for Gradio UI at ${GRADIO_URL} ..."
GRADIO_MAX_WAIT=900
GRADIO_ELAPSED=0
while ! curl -fsS --max-time 5 "${GRADIO_URL}" >/dev/null 2>&1; do
  if ! kill -0 "$GRADIO_PID" 2>/dev/null; then
    echo "❌ Gradio process exited. Last log lines:"
    tail -n 120 "$GRADIO_LOG" || true
    exit 1
  fi
  sleep 2
  GRADIO_ELAPSED=$((GRADIO_ELAPSED+2))
  if (( GRADIO_ELAPSED % 10 == 0 )); then
    echo "  ... still waiting (${GRADIO_ELAPSED}s)"
  fi
  if (( GRADIO_ELAPSED >= GRADIO_MAX_WAIT )); then
    echo "⚠️  Gradio still not responding after ${GRADIO_MAX_WAIT}s; showing recent logs and continuing."
    tail -n 200 "$GRADIO_LOG" || true
    break
  fi
done
if (( GRADIO_ELAPSED < GRADIO_MAX_WAIT )); then
  echo "✅ Gradio UI is up!"
fi

#######################################
# Summary
#######################################
echo "========================================="
echo "🎉 All services started successfully!"
echo "Gradio URL: http://${SERVER}:${PORT_GRADIO}"
echo "Local access: http://localhost:${PORT_GRADIO} (after port forwarding)"
echo "Ollama API: http://${SERVER}:${OLLAMA_PORT}"
echo "Port forward for both:"
echo "ssh -L localhost:${PORT_GRADIO}:${SERVER}:${PORT_GRADIO} -L localhost:${OLLAMA_PORT}:${SERVER}:${OLLAMA_PORT} ${USER}@neuron.ksc.re.kr"
echo "Logs:"
echo "  Ollama: $OLLAMA_LOG"
echo "  Gradio: $GRADIO_LOG"
echo "========================================="

#######################################
# Monitor with GPU stats & health checks
#######################################
LAST_HEARTBEAT=$(date +%s)
while true; do
  if ! kill -0 "$OLLAMA_PID" 2>/dev/null; then
    echo "[$(date)] ERROR: Ollama process died"
    tail -60 "$OLLAMA_LOG"
    break
  fi
  if ! kill -0 "$GRADIO_PID" 2>/dev/null; then
    echo "[$(date)] ERROR: Gradio process died"
    tail -60 "$GRADIO_LOG"
    break
  fi

  NOW=$(date +%s)
  if (( NOW - LAST_HEARTBEAT >= 300 )); then
    echo "[$(date)] 💓 Heartbeat: services running"

    echo "🔍 GPU Status:"
    nvidia-smi --query-gpu=index,name,memory.used,memory.total,utilization.gpu,temperature.gpu \
      --format=csv,noheader,nounits 2>/dev/null | \
    while IFS=',' read -r idx name used total util temp; do
      used=${used// /}; total=${total// /}; util=${util// /}; temp=${temp// /}
      mem_percent=$(( (used * 100) / (total == 0 ? 1 : total) ))
      printf "  GPU%s (%s): %sMB/%sMB (%s%%) | Util: %s%% | Temp: %s°C\n" \
        "${idx// /}" "${name}" "${used}" "${total}" "${mem_percent}" "${util}" "${temp}"
    done || true

    if curl -s --max-time 5 "http://127.0.0.1:${OLLAMA_PORT}/api/tags" >/dev/null 2>&1; then
      echo "✅ Ollama API responsive"
    else
      echo "⚠️  Ollama API not responding"
    fi

    if curl -s --max-time 5 "http://127.0.0.1:${PORT_GRADIO}" >/dev/null 2>&1; then
      echo "✅ Gradio UI responsive"
    else
      echo "⚠️  Gradio UI not responding"
    fi

    echo "----------------------------------------"
    LAST_HEARTBEAT=$NOW
  fi
  sleep 30
done
```

### Submitting the Slurm Script
- to launch both Ollama and Gradio server
```
(ollama-hpc) [glogin01]$ sbatch ollama_gradio_run_singularity.sh
Submitted batch job XXXXXX
```
- to check if the servers are up and running
```
(ollama-hpc) [glogin01]$ squeue -u $USER
             JOBID       PARTITION     NAME     USER    STATE       TIME TIME_LIMI  NODES NODELIST(REASON)
            XXXXXX    eme_h200nv_8  ollama_g    $USER  RUNNING       0:02   2-00:00:00      1 gpu##
```
- to check the SSH tunneling information generated by the ollama_gradio_run_singularity.sh script 
```
(ollama-hpc) [glogin01]$ cat port_forwarding_command_xxxxx.txt (xxxxx = jobid)
ssh -L localhost:7860:gpu50:7860 -L localhost:11434:gpu50:11434 qualis@neuron.ksc.re.kr
```

## Connecting to the Gradio UI
- Once the job starts, open a new SSH client (e.g., Putty, MobaXterm, PowerShell, Command Prompt, etc) on your local machine and run the port forwarding command displayed in port_forwarding_command_xxxxx.txt:

<img width="863" height="380" alt="Image" src="https://github.com/user-attachments/assets/0f30fa76-1022-4853-858a-cfba52116184" />

- Then, open http://localhost:7860 in your browser to access the Gradio UI and pull a gpt-oss model (for example, 'gpt-oss:latest') to the ollama server models directory (e.g., OLLAMA_MODELS="/scratch/$USER/.ollama" in the slurm script) from the [Ollama models site](https://ollama.com/search) 

<img width="1134" height="707" alt="Image" src="https://github.com/user-attachments/assets/d26f62ce-99d5-479e-a7d4-79b1bb2eb009" />


- Once the gpt-oss model is successfully downloaded, it will be listed in the 'Select Model' dropdown menu on the top right of the Gradio UI. You can start chatting with the gpt-oss model. You could also pull and chat with other models (e.g., llama3, mistral, etc) by pulling them from the Ollama models list site. 

<img width="1141" height="657" alt="Image" src="https://github.com/user-attachments/assets/5991e328-7140-40b9-a5d0-cc4bebf08157" />

## API Access

In addition to the Gradio web UI, you can interact with the Ollama server directly using its REST API. This is useful for programmatic access, automation, or integration with other tools.

### Prerequisites
- Ensure the Ollama server is running (follow the instructions above)
- Set up port forwarding if accessing from your local machine:
```bash
ssh -L localhost:11434:gpu##:11434 $USER@neuron.ksc.re.kr
```

### Basic API Commands

#### 1. List Available Models
Check which models are currently available on the server:
```bash
curl http://localhost:11434/api/tags
```

#### 2. Pull a Model
Download a model from the Ollama registry:
```bash
curl http://localhost:11434/api/pull -d '{
  "name": "gpt-oss:latest"
}'
```

For streaming progress updates:
```bash
curl http://localhost:11434/api/pull -d '{
  "name": "gpt-oss:latest",
  "stream": true
}'
```

#### 3. Generate a Response (Non-streaming)
Send a prompt and receive a complete response:
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "gpt-oss:latest",
  "prompt": "What is the capital of South Korea?",
  "stream": false
}'
```

#### 4. Generate a Response (Streaming)
For real-time streaming responses (similar to ChatGPT):
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "gpt-oss:latest",
  "prompt": "Explain quantum computing in simple terms",
  "stream": true
}'
```

#### 5. Chat Completion (Conversation)
For multi-turn conversations with context:
```bash
curl http://localhost:11434/api/chat -d '{
  "model": "gpt-oss:latest",
  "messages": [
    {
      "role": "user",
      "content": "Hello! Can you help me understand machine learning?"
    },
    {
      "role": "assistant",
      "content": "Of course! Machine learning is a subset of artificial intelligence where computers learn patterns from data."
    },
    {
      "role": "user",
      "content": "What are the main types?"
    }
  ],
  "stream": false
}'
```

#### 6. Model Information
Get detailed information about a specific model:
```bash
curl http://localhost:11434/api/show -d '{
  "name": "gpt-oss:latest"
}'
```

#### 7. Check Model Status
Verify if a model is loaded and ready:
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "gpt-oss:latest",
  "prompt": "",
  "raw": true,
  "keep_alive": 0
}'
```

### Advanced Usage

#### Custom Parameters
You can customize generation parameters for fine-tuned control:
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "gpt-oss:latest",
  "prompt": "Write a haiku about supercomputers",
  "options": {
    "temperature": 0.7,
    "top_p": 0.9,
    "top_k": 40,
    "num_predict": 100,
    "stop": ["\n\n", "###"]
  },
  "stream": false
}'
```

#### Batch Processing with Script
Create a simple bash script for batch processing:
```bash
#!/bin/bash
# batch_inference.sh

MODEL="gpt-oss:latest"
API_URL="http://localhost:11434/api/generate"

# Read prompts from file
while IFS= read -r prompt; do
  echo "Processing: $prompt"
  response=$(curl -s $API_URL -d "{
    \"model\": \"$MODEL\",
    \"prompt\": \"$prompt\",
    \"stream\": false
  }" | jq -r '.response')
  echo "Response: $response"
  echo "---"
done < prompts.txt
```

#### Python Example
For Python users, here's a simple example using the `requests` library:
```python
# ollama_test.py
import requests
import json

# API endpoint
url = "http://localhost:11434/api/generate"

# Request payload
payload = {
    "model": "gpt-oss:latest",
    "prompt": "What are the benefits of using HPC for AI research?",
    "stream": False
}

# Send request
response = requests.post(url, json=payload)

# Parse and print response
if response.status_code == 200:
    result = response.json()
    print(result['response'])
else:
    print(f"Error: {response.status_code}")
```

#### Monitoring API Health
Check if the Ollama API is responsive:
```bash
#!/bin/bash
# health_check.sh

check_ollama() {
    if curl -s --max-time 5 http://localhost:11434/api/tags > /dev/null 2>&1; then
        echo "✅ Ollama API is healthy"
        return 0
    else
        echo "❌ Ollama API is not responding"
        return 1
    fi
}

# Run health check
check_ollama
```

### API Response Format

#### Successful Generation Response:
```json
{
  "model": "gpt-oss:latest",
  "created_at": "2025-01-15T10:30:00.000Z",
  "response": "Seoul is the capital of South Korea.",
  "done": true,
  "context": [1, 2, 3, ...],
  "total_duration": 5043869416,
  "load_duration": 5876490,
  "prompt_eval_count": 26,
  "prompt_eval_duration": 325953000,
  "eval_count": 290,
  "eval_duration": 4709213000
}
```

#### Streaming Response Format:
Each line is a JSON object when streaming is enabled:
```json
{"model":"gpt-oss:latest","created_at":"2025-01-15T10:30:00.000Z","response":"The","done":false}
{"model":"gpt-oss:latest","created_at":"2025-01-15T10:30:00.001Z","response":" capital","done":false}
{"model":"gpt-oss:latest","created_at":"2025-01-15T10:30:00.002Z","response":" of","done":false}
...
{"model":"gpt-oss:latest","created_at":"2025-01-15T10:30:01.000Z","response":"","done":true,"total_duration":1000000000}
```

### Performance Tips

1. **Keep Models Warm**: Use the `keep_alive` parameter to keep models loaded in memory:
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "gpt-oss:latest",
  "keep_alive": "30m"
}'
```

2. **Batch Requests**: Process multiple prompts efficiently by keeping the model loaded between requests

3. **Optimize Context**: For long conversations, manage context size to balance performance and memory:
```bash
curl http://localhost:11434/api/generate -d '{
  "model": "gpt-oss:latest",
  "prompt": "Your prompt here",
  "options": {
    "num_ctx": 4096
  }
}'
```

### Troubleshooting API Access

If you encounter issues:

1. **Connection Refused**: Ensure port forwarding is active and the Ollama server is running
2. **Model Not Found**: Verify the model is pulled using the list models command
3. **Timeout Issues**: Large models may take time to load initially; increase timeout values
4. **Memory Errors**: Check GPU memory availability with `nvidia-smi`

For more detailed API documentation, refer to the [Ollama API Documentation](https://github.com/ollama/ollama/blob/main/docs/api.md).
