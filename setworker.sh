#!/bin/bash

# Remove the specific GOMAXPROCS line from the [Install] section
sed -i '/^\[Install\]/,/^\[/{/Environment=GOMAXPROCS=2/d;}' /lib/systemd/system/ceremonyclient.service

# Get the number of CPU cores
cores=$(nproc)

# Calculate GOMAXPROCS as 40% of the total cores
gomaxprocs=$(awk "BEGIN {print int($cores * 0.25)}")

# Ensure GOMAXPROCS is at least 4
gomaxprocs=$((gomaxprocs >= 4 ? gomaxprocs : 4))

# Print calculated values for debugging
echo "Number of CPU cores: $cores"
echo "Calculated GOMAXPROCS: $gomaxprocs"

# Update or add Environment=GOMAXPROCS in the [Service] section of the service file
service_file="/lib/systemd/system/ceremonyclient.service"
if grep -q "^\[Service\]" "$service_file"; then
  sed -i "/^\[Service\]/,/^\[/{/Environment=GOMAXPROCS=/d;}" "$service_file"
  sed -i "/^\[Service\]/a Environment=GOMAXPROCS=$gomaxprocs" "$service_file"
else
  echo -e "\n[Service]\nEnvironment=GOMAXPROCS=$gomaxprocs" >> "$service_file"
fi

# Remove CPUQuota if it exists in the service file
if grep -q "^CPUQuota=" "$service_file"; then
  sed -i "/^CPUQuota=/d" "$service_file"
fi

# Reload systemd configuration
sudo systemctl daemon-reload

# Restart the service
sudo systemctl restart ceremonyclient.service

echo "The script has successfully updated GOMAXPROCS to $gomaxprocs, removed CPUQuota (if it existed), and restarted the service."
