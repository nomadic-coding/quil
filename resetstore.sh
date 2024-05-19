#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if unzip is installed
if ! command_exists unzip; then
  echo "unzip is not installed. Installing..."
  sudo apt-get update
  sudo apt-get -y install unzip
  echo "unzip installed successfully."
else
  echo "unzip is already installed."
fi

# Check if tmux is installed
if command_exists tmux; then
  # Check if any tmux sessions are running
  if tmux ls >/dev/null 2>&1; then
    echo "tmux sessions are running. Killing all tmux sessions..."
    tmux kill-server
    echo "All tmux sessions killed."
  else
    echo "No tmux sessions are running."
  fi
else
  echo "tmux is not installed."
fi


# Define the file path and the download URL
REPAIR_FILE="/root/REPAIR"
DOWNLOAD_URL="http://91.188.254.197:10001/REPAIR"

# Check if the file exists
if [ ! -f "$REPAIR_FILE" ]; then
  echo "REPAIR file does not exist. Downloading..."
  curl -L -o "$REPAIR_FILE" "$DOWNLOAD_URL"
  echo "Download completed: $REPAIR_FILE"
else
  echo "REPAIR file already exists: $REPAIR_FILE"
fi

# Define the STORE file and the directory
STORE_FILE="/root/store368411.zip"
STORE_FILE_URL="http://91.188.254.197:10001/store368411.zip"
STORE_DIR="/root/store"

# Download the STORE file if it doesn't exist
if [ ! -f "$STORE_FILE" ]; then
  echo "STORE file does not exist. Downloading..."
  curl -L -o "$STORE_FILE" "$STORE_FILE_URL"
  echo "Download completed: $STORE_FILE"
else
  echo "STORE file already exists: $STORE_FILE"
fi

# Check if the STORE directory exists and has files
if [ -d "$STORE_DIR" ]; then
  if [ -z "$(ls -A $STORE_DIR)" ]; then
    echo "STORE directory is empty. Unzipping $STORE_FILE..."
    unzip -o -j "$STORE_FILE" -d "$STORE_DIR"
    echo "Unzip completed: $STORE_FILE to $STORE_DIR"
  else
    echo "STORE directory is not empty."
  fi
else
  echo "STORE directory does not exist. Creating and unzipping $STORE_FILE..."
  mkdir -p "$STORE_DIR"
  unzip -o -j "$STORE_FILE" -d "$STORE_DIR"
  echo "Unzip completed: $STORE_FILE to $STORE_DIR"
fi

rm -rf /root/ceremonyclient/node/.config/store/*
cd /root/
cp -r /root/store/* /root/ceremonyclient/node/.config/store/
cp /root/REPAIR /root/ceremonyclient/node/.config/REPAIR

tmux new-session -d -s quil 'export PATH=$PATH:/usr/local/go/bin && cd /root/ceremonyclient/node && /root/scripts/qnode_restart.sh'
