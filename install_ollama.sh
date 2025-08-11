#!/bin/bash

# 1. Create Ollama installation directory
user="$USER"  # Or use $UID for more robustness in some edge cases
install_dir="/scratch/$user/ollama"

mkdir -p "$install_dir"  # -p creates parent directories if needed

# 2. Change directory and download
cd "$install_dir" || { echo "Error: Could not change directory to $install_dir"; exit 1; }

wget "https://ollama.com/download/ollama-linux-amd64.tgz" || { echo "Error: Could not download Ollama"; exit 1; }

# 3. Unzip/untar
tar -xvzf ollama-linux-amd64.tgz || { echo "Error: Could not extract Ollama"; exit 1; }

# Clean up the tar file (optional)
rm ollama-linux-amd64.tgz


# 4. Add to ~/.bashrc (more robust approach)
bashrc_file="$HOME/.bashrc"

# Check if the path is already in .bashrc to avoid duplicates
if ! grep -q "$install_dir/bin" "$bashrc_file"; then
  echo "export PATH=\$PATH:$install_dir/bin" >> "$bashrc_file"
  echo "Ollama path added to ~/.bashrc.  source ~/.bashrc or restart your terminal for changes to take effect."
else
    echo "Ollama path is already in ~/.bashrc"
fi


# Optional: Make the ollama binary executable (if needed - usually not necessary with the official .tgz)
# chmod +x "$install_dir/$ollama_extracted_dir/bin/ollama"

echo "Ollama installation complete."
