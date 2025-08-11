#!/bin/sh
# This script installs Ollama on Linux in user's scratch directory.
# It detects the current operating system architecture and installs the appropriate version of Ollama.

set -eu

# Script version
SCRIPT_VERSION="1.1.0"

# Color definitions
red="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 1 || :) 2>&-)"
green="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 2 || :) 2>&-)"
yellow="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 3 || :) 2>&-)"
blue="$( (/usr/bin/tput bold || :; /usr/bin/tput setaf 4 || :) 2>&-)"
plain="$( (/usr/bin/tput sgr0 || :) 2>&-)"

# Default values
OLLAMA_VERSION=""
INSTALL_DIR_BASE="/scratch/${USER}"
FORCE_INSTALL=false
VERBOSE=false

# Functions for output
status() { echo "${green}>>>${plain} $*" >&2; }
error() { echo "${red}ERROR:${plain} $*" >&2; exit 1; }
warning() { echo "${yellow}WARNING:${plain} $*" >&2; }
info() { echo "${blue}INFO:${plain} $*" >&2; }
verbose() { if [ "$VERBOSE" = true ]; then echo "${blue}DEBUG:${plain} $*" >&2; fi; }

# Help function
show_help() {
    cat << EOF
${green}Ollama User Installation Script${plain} v${SCRIPT_VERSION}

${yellow}USAGE:${plain}
    $0 [OPTIONS] [VERSION]

${yellow}DESCRIPTION:${plain}
    Installs Ollama on Linux in user's scratch directory without requiring sudo.
    Automatically detects system architecture and GPU availability.

${yellow}ARGUMENTS:${plain}
    VERSION             Specific Ollama version to install (e.g., 0.3.14)
                       If not specified, installs the latest version

${yellow}OPTIONS:${plain}
    -h, --help         Show this help message and exit
    -v, --verbose      Enable verbose output
    -f, --force        Force reinstallation even if Ollama exists
    -d, --dir DIR      Custom installation directory (default: /scratch/\$USER/ollama)
    -V, --version      Show script version and exit
    --list-gpu         Check GPU availability and exit

${yellow}EXAMPLES:${plain}
    # Install latest version
    $0

    # Install specific version
    $0 0.3.14

    # Install with custom directory
    $0 --dir /home/\$USER/.local/ollama 0.3.14

    # Force reinstall with verbose output
    $0 -fv 0.3.14

    # Check GPU status
    $0 --list-gpu

${yellow}INSTALLATION DIRECTORY:${plain}
    Default: ${INSTALL_DIR_BASE}/ollama
    Binaries: ${INSTALL_DIR_BASE}/ollama/bin
    Libraries: ${INSTALL_DIR_BASE}/ollama/lib/ollama

${yellow}POST-INSTALLATION:${plain}
    After installation, add the following to your ~/.bashrc or ~/.profile:
    export PATH="${INSTALL_DIR_BASE}/ollama/bin:\$PATH"

${yellow}GPU SUPPORT:${plain}
    - NVIDIA: Requires NVIDIA drivers (installed by system admin)
    - AMD: Downloads ROCm-enabled version if AMD GPU detected
    - CPU: Falls back to CPU-only mode if no GPU detected

${yellow}NOTES:${plain}
    - This script requires Linux (WSL2 supported, WSL1 not supported)
    - No sudo/root privileges required
    - GPU drivers must be pre-installed by system administrator

${yellow}HOMEPAGE:${plain}
    https://ollama.com
    https://github.com/ollama/ollama

EOF
}

# Show version
show_version() {
    echo "Ollama User Installation Script v${SCRIPT_VERSION}"
    exit 0
}

# GPU detection function
check_gpu_status() {
    echo "${green}Checking GPU availability...${plain}"
    echo ""
    
    # Check for NVIDIA
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "${green}NVIDIA GPU Status:${plain}"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader || echo "  Unable to query NVIDIA GPU"
        echo ""
    elif command -v lspci >/dev/null 2>&1 && lspci -d '10de:' | grep -q 'NVIDIA'; then
        echo "${yellow}NVIDIA GPU detected but nvidia-smi not available${plain}"
        echo "  NVIDIA drivers may not be installed"
        echo ""
    fi
    
    # Check for AMD
    if command -v rocm-smi >/dev/null 2>&1; then
        echo "${green}AMD GPU Status:${plain}"
        rocm-smi --showproductname || echo "  Unable to query AMD GPU"
        echo ""
    elif command -v lspci >/dev/null 2>&1 && lspci -d '1002:' | grep -q 'AMD'; then
        echo "${yellow}AMD GPU detected but ROCm not available${plain}"
        echo "  ROCm drivers may not be installed"
        echo ""
    fi
    
    # Check for Jetson
    if [ -f /etc/nv_tegra_release ]; then
        echo "${green}NVIDIA Jetson Platform detected${plain}"
        cat /etc/nv_tegra_release
        echo ""
    fi
    
    # If no GPU detected
    if ! command -v nvidia-smi >/dev/null 2>&1 && \
       ! command -v rocm-smi >/dev/null 2>&1 && \
       ! [ -f /etc/nv_tegra_release ] && \
       ! (command -v lspci >/dev/null 2>&1 && (lspci | grep -E 'NVIDIA|AMD' -q)); then
        echo "${yellow}No GPU detected - Ollama will run in CPU-only mode${plain}"
    fi
    
    exit 0
}

# Parse command line arguments
parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -V|--version)
                show_version
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            -d|--dir)
                if [ -z "${2:-}" ]; then
                    error "Option --dir requires an argument"
                fi
                INSTALL_DIR_BASE="$2"
                shift 2
                ;;
            --list-gpu)
                check_gpu_status
                ;;
            -*)
                error "Unknown option: $1\nRun '$0 --help' for usage information"
                ;;
            *)
                # Assume it's a version number
                if [ -z "$OLLAMA_VERSION" ]; then
                    OLLAMA_VERSION="$1"
                    verbose "Version specified: $OLLAMA_VERSION"
                else
                    error "Multiple version numbers specified. Please provide only one version."
                fi
                shift
                ;;
        esac
    done
}

# Main installation logic starts here
parse_args "$@"

# Set installation directory
OLLAMA_INSTALL_DIR="${INSTALL_DIR_BASE}/ollama"
BINDIR="${OLLAMA_INSTALL_DIR}/bin"

# Show installation summary
if [ "$VERBOSE" = true ]; then
    info "Installation Configuration:"
    info "  Version: ${OLLAMA_VERSION:-latest}"
    info "  Install Directory: $OLLAMA_INSTALL_DIR"
    info "  Force Reinstall: $FORCE_INSTALL"
    echo ""
fi

TEMP_DIR=$(mktemp -d)
cleanup() { rm -rf $TEMP_DIR; }
trap cleanup EXIT

available() { command -v $1 >/dev/null; }
require() {
    local MISSING=''
    for TOOL in $*; do
        if ! available $TOOL; then
            MISSING="$MISSING $TOOL"
        fi
    done

    echo $MISSING
}

[ "$(uname -s)" = "Linux" ] || error 'This script is intended to run on Linux only.'

ARCH=$(uname -m)
case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) error "Unsupported architecture: $ARCH" ;;
esac

verbose "Detected architecture: $ARCH"

IS_WSL2=false

KERN=$(uname -r)
case "$KERN" in
    *icrosoft*WSL2 | *icrosoft*wsl2) 
        IS_WSL2=true
        verbose "WSL2 environment detected"
        ;;
    *icrosoft) 
        error "Microsoft WSL1 is not currently supported. Please use WSL2 with 'wsl --set-version <distro> 2'" 
        ;;
    *) ;;
esac

VER_PARAM="${OLLAMA_VERSION:+?version=$OLLAMA_VERSION}"

# NO SUDO - installing to user directory
SUDO=""

NEEDS=$(require curl awk grep sed tee xargs)
if [ -n "$NEEDS" ]; then
    error "The following tools are required but missing:$(echo $NEEDS | xargs -n1 echo "  -")"
fi

# Check if Ollama is already installed
if [ -f "$BINDIR/ollama" ] && [ "$FORCE_INSTALL" = false ]; then
    INSTALLED_VERSION=$("$BINDIR/ollama" --version 2>/dev/null || echo "unknown")
    warning "Ollama is already installed (version: $INSTALLED_VERSION) at $OLLAMA_INSTALL_DIR"
    echo "Use -f or --force to reinstall"
    exit 0
fi

# Create directories if they don't exist
status "Creating installation directories..."
mkdir -p "$BINDIR"
mkdir -p "$OLLAMA_INSTALL_DIR/lib/ollama"

if [ -d "$OLLAMA_INSTALL_DIR/lib/ollama" ] && [ "$FORCE_INSTALL" = true ]; then
    status "Cleaning up old version at $OLLAMA_INSTALL_DIR/lib/ollama"
    rm -rf "$OLLAMA_INSTALL_DIR/lib/ollama"
fi

status "Installing Ollama ${OLLAMA_VERSION:-latest} to $OLLAMA_INSTALL_DIR"
mkdir -p "$OLLAMA_INSTALL_DIR/lib/ollama"

status "Downloading Linux ${ARCH} bundle"
DOWNLOAD_URL="https://ollama.com/download/ollama-linux-${ARCH}.tgz${VER_PARAM}"
verbose "Download URL: $DOWNLOAD_URL"

curl --fail --show-error --location --progress-bar "$DOWNLOAD_URL" | \
    tar -xzf - -C "$OLLAMA_INSTALL_DIR" || \
    error "Failed to download or extract Ollama. Please check your internet connection and verify the version number."

# Create symlink if ollama binary is not directly in bin directory
if [ "$OLLAMA_INSTALL_DIR/bin/ollama" != "$BINDIR/ollama" ] && [ -f "$OLLAMA_INSTALL_DIR/ollama" ]; then
    verbose "Creating symlink for ollama binary"
    ln -sf "$OLLAMA_INSTALL_DIR/ollama" "$BINDIR/ollama"
fi

# Check for NVIDIA JetPack systems with additional downloads
if [ -f /etc/nv_tegra_release ] ; then
    if grep R36 /etc/nv_tegra_release > /dev/null ; then
        status "Downloading JetPack 6 components"
        curl --fail --show-error --location --progress-bar \
            "https://ollama.com/download/ollama-linux-${ARCH}-jetpack6.tgz${VER_PARAM}" | \
            tar -xzf - -C "$OLLAMA_INSTALL_DIR"
    elif grep R35 /etc/nv_tegra_release > /dev/null ; then
        status "Downloading JetPack 5 components"
        curl --fail --show-error --location --progress-bar \
            "https://ollama.com/download/ollama-linux-${ARCH}-jetpack5.tgz${VER_PARAM}" | \
            tar -xzf - -C "$OLLAMA_INSTALL_DIR"
    else
        warning "Unsupported JetPack version detected. GPU may not be supported"
    fi
fi

install_success() {
    echo ""
    echo "${green}════════════════════════════════════════════════════════════════${plain}"
    echo "${green}Installation Complete!${plain}"
    echo "${green}════════════════════════════════════════════════════════════════${plain}"
    echo ""
    
    # Check if installed version can be determined
    if [ -f "$BINDIR/ollama" ]; then
        INSTALLED_VER=$("$BINDIR/ollama" --version 2>/dev/null || echo "")
        if [ -n "$INSTALLED_VER" ]; then
            info "Installed: $INSTALLED_VER"
        fi
    fi
    
    echo "${yellow}Next Steps:${plain}"
    echo "1. Add Ollama to your PATH by adding this line to ~/.bashrc or ~/.profile:"
    echo "   ${blue}export PATH=\"$BINDIR:\$PATH\"${plain}"
    echo ""
    echo "2. Reload your shell configuration:"
    echo "   ${blue}source ~/.bashrc${plain}"
    echo ""
    echo "3. Start the Ollama server:"
    echo "   ${blue}ollama serve${plain}"
    echo ""
    echo "4. In another terminal, run a model:"
    echo "   ${blue}ollama run llama2${plain}"
    echo ""
    info "The Ollama API will be available at ${blue}http://127.0.0.1:11434${plain}"
    
    if [ "$VERBOSE" = true ]; then
        echo ""
        info "Installation details:"
        info "  Binary: $BINDIR/ollama"
        info "  Libraries: $OLLAMA_INSTALL_DIR/lib/ollama"
    fi
}
trap install_success EXIT

# Skip systemd configuration for user installation
verbose "Skipping systemd configuration (user installation)"

# WSL2 only supports GPUs via nvidia passthrough
# so check for nvidia-smi to determine if GPU is available
if [ "$IS_WSL2" = true ]; then
    if available nvidia-smi && [ -n "$(nvidia-smi | grep -o "CUDA Version: [0-9]*\.[0-9]*")" ]; then
        status "Nvidia GPU detected in WSL2"
    fi
    install_success
    exit 0
fi

# Don't attempt to install drivers on Jetson systems
if [ -f /etc/nv_tegra_release ] ; then
    status "NVIDIA JetPack ready"
    install_success
    exit 0
fi

# Install GPU dependencies on Linux (check only, no driver installation for user install)
if ! available lspci && ! available lshw; then
    warning "Unable to detect NVIDIA/AMD GPU. Install lspci or lshw to automatically detect GPU type"
    install_success
    exit 0
fi

check_gpu() {
    # Look for devices based on vendor ID for NVIDIA and AMD
    case $1 in
        lspci)
            case $2 in
                nvidia) available lspci && lspci -d '10de:' | grep -q 'NVIDIA' || return 1 ;;
                amdgpu) available lspci && lspci -d '1002:' | grep -q 'AMD' || return 1 ;;
            esac ;;
        lshw)
            case $2 in
                nvidia) available lshw && lshw -c display -numeric -disable network | grep -q 'vendor: .* \[10DE\]' || return 1 ;;
                amdgpu) available lshw && lshw -c display -numeric -disable network | grep -q 'vendor: .* \[1002\]' || return 1 ;;
            esac ;;
        nvidia-smi) available nvidia-smi || return 1 ;;
    esac
}

if check_gpu nvidia-smi; then
    status "NVIDIA GPU detected and drivers appear to be installed"
    install_success
    exit 0
fi

if ! check_gpu lspci nvidia && ! check_gpu lshw nvidia && ! check_gpu lspci amdgpu && ! check_gpu lshw amdgpu; then
    install_success
    warning "No NVIDIA/AMD GPU detected. Ollama will run in CPU-only mode"
    exit 0
fi

if check_gpu lspci amdgpu || check_gpu lshw amdgpu; then
    status "Downloading Linux ROCm ${ARCH} bundle"
    curl --fail --show-error --location --progress-bar \
        "https://ollama.com/download/ollama-linux-${ARCH}-rocm.tgz${VER_PARAM}" | \
        tar -xzf - -C "$OLLAMA_INSTALL_DIR"

    install_success
    status "AMD GPU ready"
    exit 0
fi

# For user installation, we skip CUDA driver installation as it requires root
if check_gpu lspci nvidia || check_gpu lshw nvidia; then
    warning "NVIDIA GPU detected but drivers may not be installed"
    warning "GPU acceleration requires NVIDIA drivers to be installed by system administrator"
    warning "Ollama will fall back to CPU-only mode if GPU drivers are not available"
fi

status "Installation complete. GPU support depends on system-installed drivers"
install_success

