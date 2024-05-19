#!/bin/bash

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check if pip is installed
if ! command_exists pip; then
  echo "pip is not installed. Installing..."
  sudo apt-get update
  sudo apt-get -y install python3-pip
  echo "pip installed successfully."
else
  echo "pip is already installed."
fi

# Check if gdown is installed
if ! command_exists gdown; then
  echo "gdown is not installed. Installing..."
  pip install gdown
  echo "gdown installed successfully."
else
  echo "gdown is already installed."
fi

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

# Define the STORE file and the directory
STORE_FILE="/root/store368411.zip"
STORE_FILE_ID="1XPmG9vmG3VEH_ZE1wiyP2gBfW2zcMi5q"
STORE_DIR="/root/store"

# Function to download file from Google Drive using gdown
download_from_google_drive() {
  local file_id=$1
  local destination=$2
  gdown --id "$file_id" --output "$destination"
}

# Download the STORE file from Google Drive if it doesn't exist
if [ ! -f "$STORE_FILE" ]; then
  echo "STORE file does not exist. Downloading..."
  download_from_google_drive "$STORE_FILE_ID" "$STORE_FILE"
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
