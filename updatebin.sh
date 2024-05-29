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

# Check if curl is installed
if ! command_exists curl; then
  echo "curl is not installed. Installing..."
  sudo apt-get update
  sudo apt-get -y install curl
  echo "curl installed successfully."
else
  echo "curl is already installed."
fi

# Check if wget is installed
if ! command_exists wget; then
  echo "wget is not installed. Installing..."
  sudo apt-get update
  sudo apt-get -y install wget
  echo "wget installed successfully."
else
  echo "wget is already installed."
fi

echo "stop running service"
kill -9 $(pgrep node-1.4.18) && service ceremonyclient stop

# Define the node.tar.gz file path and the download URL
NODE_FILE="/root/node.tar.gz"
DOWNLOAD_URL="http://91.188.254.197:10001/node.tar.gz"
TARGET_DIR="/root/ceremonyclient/node/"

# Check if the file exists
if [ ! -f "$NODE_FILE" ]; then
  echo "node.tar.gz file does not exist. Downloading..."
  curl -L -o "$NODE_FILE" "$DOWNLOAD_URL"
  echo "Download completed: $NODE_FILE"
else
  echo "node.tar.gz file already exists: $NODE_FILE"
fi

# Extract the tar.gz file
echo "Extracting $NODE_FILE..."
tar -xzvf "$NODE_FILE" -C /root/
echo "Extraction completed."

# Move the extracted files to the target directory
echo "Moving files to $TARGET_DIR..."
mv node-1.4.18-linux-amd64* $TARGET_DIR
echo "Files moved to $TARGET_DIR."

service ceremonyclient start

echo "starting service"
