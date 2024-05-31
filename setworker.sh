#!/bin/bash

# Get the number of CPU cores
cores=$(nproc)

# Get the total RAM in gigabytes using /proc/meminfo
ram_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
ram=$((ram_kb / 1024 / 1024))  # Convert from KB to GB

# Calculate GOMAXPROCS
# Set max_cores to 40% of the total cores or the number of potential GOMAXPROCS based on available RAM, whichever is lower
required_ram_per_core=2
max_cores_by_ram=$((ram / required_ram_per_core))
max_cores_by_cores=$(awk "BEGIN {print int($cores * 0.4)}")
max_cores=$((max_cores_by_ram < max_cores_by_cores ? max_cores_by_ram : max_cores_by_cores))

# Ensure max_cores is at least 1
max_cores=$((max_cores > 0 ? max_cores : 1))

# Set GOMAXPROCS to the calculated max_cores
gomaxprocs=$max_cores

# Print calculated values for debugging
echo "Number of CPU cores: $cores"
echo "Total RAM in GB: $ram"
echo "Calculated max_cores: $max_cores"
echo "Calculated GOMAXPROCS: $gomaxprocs"

# Update or add Environment=GOMAXPROCS in the service file
if grep -q "^Environment=GOMAXPROCS=" /lib/systemd/system/ceremonyclient.service; then
  sudo sed -i "/^Environment=GOMAXPROCS=/c\Environment=GOMAXPROCS=$gomaxprocs" /lib/systemd/system/ceremonyclient.service
else
  sudo sed -i "/\[Service\]/a Environment=GOMAXPROCS=$gomaxprocs" /lib/systemd/system/ceremonyclient.service
fi

# Remove CPUQuota if it exists in the service file
if grep -q "^CPUQuota=" /lib/systemd/system/ceremonyclient.service; then
  sudo sed -i "/^CPUQuota=/d" /lib/systemd/system/ceremonyclient.service
fi

# Reload systemd configuration
sudo systemctl daemon-reload

# Restart the service
sudo systemctl restart ceremonyclient.service
