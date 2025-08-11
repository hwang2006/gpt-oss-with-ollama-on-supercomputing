#!/bin/bash
#SBATCH --job-name=ollama_gradio
#SBATCH --comment=pytorch
##SBATCH --partition=mig_amd_a100_4
##SBATCH --partition=gh200_1
##SBATCH --partition=eme_h200nv_8
#SBATCH --partition=amd_a100nv_8
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
