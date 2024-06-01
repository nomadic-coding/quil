#!/bin/bash

# Check if the GOMAXPROCS value is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <GOMAXPROCS_value>"
  exit 1
fi

# Get the GOMAXPROCS value from the first argument
gomaxprocs=$1

# Check if the input is a valid number
if ! [[ "$gomaxprocs" =~ ^[0-9]+$ ]]; then
  echo "Invalid input. Please enter a numeric value."
  exit 1
fi

# Define the service file path
service_file="/lib/systemd/system/ceremonyclient.service"

# Backup the original service file
cp "$service_file" "$service_file.bak"

# Update the GOMAXPROCS value in the service file or add it if it doesn't exist
if grep -q "^Environment=GOMAXPROCS=" "$service_file"; then
  sed -i "s/^Environment=GOMAXPROCS=.*$/Environment=GOMAXPROCS=$gomaxprocs/" "$service_file"
else
  echo "Environment=GOMAXPROCS=$gomaxprocs" >> "$service_file"
fi

# Remove CPUQuota= line if it exists
sed -i "/^CPUQuota=/d" "$service_file"

# Reload the systemd manager configuration
systemctl daemon-reload

# Restart the service to apply changes
systemctl restart ceremonyclient.service

echo "GOMAXPROCS has been updated to $gomaxprocs in $service_file, CPUQuota= has been removed (if it existed), and the service has been restarted."
