#!/bin/bash

# Define the file path
CONFIG_FILE="/root/ceremonyclient/node/.config/config.yml"

# Replace the listenMultiaddr line
sed -i 's|listenMultiaddr: /ip4/0.0.0.0/udp/8336/quic|listenMultiaddr: /ip4/0.0.0.0/tcp/8336|' "$CONFIG_FILE"


echo "Replacement done in $CONFIG_FILE"

ufw allow 8336/tcp

echo "restarting service"
service ceremonyclient restart
