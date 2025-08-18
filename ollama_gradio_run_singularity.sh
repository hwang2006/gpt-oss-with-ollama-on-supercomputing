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
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --gres=gpu:1
#SBATCH --cpus-per-task=8

set +e

#######################################
# Config you may tweak
#######################################
SERVER="$(hostname)"
GRADIO_PORT=7860
OLLAMA_PORT=11434

# Set a model to preload/warm in the UI; set to 0 to disable preloading
#DEFAULT_MODEL="gemma:latest"
#DEFAULT_MODEL="gpt-oss:latest"
DEFAULT_MODEL=0

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
# Cleanup — kill only what we started
#######################################
cleanup() {
  echo "[$(date)] Cleaning up processes..."

  # Try to gracefully stop models (best effort; ignore failures)
  if curl -fsS --max-time 2 "http://127.0.0.1:${OLLAMA_PORT}/api/ps" >/dev/null 2>&1; then
    singularity exec --nv ./ollama_latest.sif ollama stop all >/dev/null 2>&1 || true
  fi

  # Kill Gradio (PID we launched)
  if [ -n "${GRADIO_PID:-}" ] && kill -0 "$GRADIO_PID" 2>/dev/null; then
    kill -TERM "$GRADIO_PID" 2>/dev/null || true
    sleep 2
    kill -KILL "$GRADIO_PID" 2>/dev/null || true
  fi

  # Kill the entire Ollama serve process group (that we created with setsid)
  if [ -n "${OLLAMA_PGID:-}" ]; then
    kill -TERM -- -"${OLLAMA_PGID}" 2>/dev/null || true
    sleep 3
    kill -KILL -- -"${OLLAMA_PGID}" 2>/dev/null || true
  elif [ -n "${OLLAMA_PID:-}" ] && kill -0 "$OLLAMA_PID" 2>/dev/null; then
    # Fallback: kill by parent PID (children first)
    pkill -TERM -P "$OLLAMA_PID" 2>/dev/null || true
    kill -TERM "$OLLAMA_PID" 2>/dev/null || true
    sleep 3
    pkill -KILL -P "$OLLAMA_PID" 2>/dev/null || true
    kill -KILL "$OLLAMA_PID" 2>/dev/null || true
  fi

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
echo "Gradio Port: $GRADIO_PORT"
echo "Ollama Port: $OLLAMA_PORT"
echo "Default Model: $DEFAULT_MODEL"
echo "========================================"
echo "ssh -L localhost:${GRADIO_PORT}:${SERVER}:${GRADIO_PORT} -L localhost:${OLLAMA_PORT}:${SERVER}:${OLLAMA_PORT} ${USER}@neuron.ksc.re.kr" > "$PORT_FWD_FILE"

#######################################
# Env / modules
#######################################
if [ -f /etc/profile.d/modules.sh ]; then . /etc/profile.d/modules.sh; fi
module load gcc/10.2.0 cuda/12.1

# Activate conda environment
source ~/.bashrc
conda activate ollama-hpc

#######################################
# Clean stale logs / procs (narrow match)
#######################################
pkill -f "ollama serve" 2>/dev/null || true
pkill -f "ollama_web.py" 2>/dev/null || true
rm -f "$OLLAMA_LOG" "$GRADIO_LOG"

#######################################
# Start Ollama (Singularity RUN) in its own process group
#######################################
echo "🚀 Starting Ollama server..."
cd "$WORK_DIR"  # ensure ollama_latest.sif is here

# Launch in a new session so we can kill just this group later
nohup setsid singularity run --nv \
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
# Get the process group id of the singularity process we just started
OLLAMA_PGID="$(ps -o pgid= "$OLLAMA_PID" | tr -d ' ')"
echo "Ollama PID: $OLLAMA_PID (PGID: $OLLAMA_PGID)"

#######################################
# Wait for Ollama API
#######################################
MAX_WAIT=180
COUNTER=0
while [ $COUNTER -lt $MAX_WAIT ]; do
  if curl -s "http://127.0.0.1:${OLLAMA_PORT}/api/tags" >/dev/null; then
    echo "✅ Ollama API is up!"
    break
  fi
  COUNTER=$((COUNTER + 2))
  echo "Waiting for Ollama API... (${COUNTER}s)"
  sleep 2
done
if [ $COUNTER -ge $MAX_WAIT ]; then
  echo "❌ Ollama API startup timeout"
  tail -60 "$OLLAMA_LOG" || true
  exit 1
fi

#######################################
# Start Gradio (UI reads DEFAULT_MODEL & may preload it)
#######################################
echo "🌐 Starting Gradio web interface..."

export DEFAULT_MODEL
nohup python ollama_web.py --host=0.0.0.0 --port=${GRADIO_PORT} > "$GRADIO_LOG" 2>&1 &
GRADIO_PID=$!
echo "Gradio PID: $GRADIO_PID"

#######################################
# Wait for Gradio UI
#######################################
GRADIO_URL="http://127.0.0.1:${GRADIO_PORT}/"
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
echo "Gradio URL: http://${SERVER}:${GRADIO_PORT}"
echo "Local access: http://localhost:${GRADIO_PORT} (after port forwarding)"
echo "Ollama API: http://${SERVER}:${OLLAMA_PORT}"
echo "Port forward for both:"
echo "ssh -L localhost:${GRADIO_PORT}:${SERVER}:${GRADIO_PORT} -L localhost:${OLLAMA_PORT}:${SERVER}:${OLLAMA_PORT} ${USER}@neuron.ksc.re.kr"
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
    tail -60 "$OLLAMA_LOG" || true
    break
  fi
  if ! kill -0 "$GRADIO_PID" 2>/dev/null; then
    echo "[$(date)] ERROR: Gradio process died"
    tail -60 "$GRADIO_LOG" || true
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

    if curl -s --max-time 5 "http://127.0.0.1:${GRADIO_PORT}" >/dev/null 2>&1; then
      echo "✅ Gradio UI responsive"
    else
      echo "⚠️  Gradio UI not responding"
    fi

    echo "----------------------------------------"
    LAST_HEARTBEAT=$NOW
  fi
  sleep 30
done

