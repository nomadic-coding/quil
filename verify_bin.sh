#!/bin/bash

# Ensure OpenSSL is installed
sudo apt-get install -y openssl

# Define the directory containing the files
DIR="/root/ceremonyclient/node"

# Find the binary file matching the pattern
FILE=$(ls $DIR/node-*-linux-amd64)

# Define the corresponding digest file
DGST_FILE="${FILE}.dgst"

# Extract the expected hash from the digest file
EXPECTED_HASH=$(grep -oP "SHA3-256\($(basename $FILE)\)= \K[0-9a-f]{64}" $DGST_FILE)

# Calculate the actual hash of the file using OpenSSL
ACTUAL_HASH=$(openssl dgst -sha3-256 $FILE | awk '{ print $NF }')

# Compare the expected and actual hashes and print the result
if [ "$EXPECTED_HASH" == "$ACTUAL_HASH" ]; then
  echo "sha3-256 ok"
else
  echo "sha3-256 failed"
fi
