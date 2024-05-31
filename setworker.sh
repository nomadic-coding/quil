#!/bin/bash

kill -9 $(pgrep node-1.4.18) && service ceremonyclient stop

# Get the number of CPU cores
cores=$(nproc)

# Get the total RAM in gigabytes
ram=$(free -g | awk '/^Mem:/{print $2}')

# Calculate GOMAXPROCS
# For example, if it has 4 cores, it should set GOMAXPROCS=6, but it needs at least 2GB RAM per core
required_ram_per_core=2
maxprocs=$((cores + 2))  # Base GOMAXPROCS calculation

# Adjust GOMAXPROCS based on available RAM
if (( ram < cores * required_ram_per_core )); then
  maxprocs=$((ram / required_ram_per_core))
fi

# Ensure GOMAXPROCS is at least 1
gomaxprocs=$((maxprocs > 0 ? maxprocs : 1))

# Print calculated values for debugging
echo "Number of CPU cores: $cores"
echo "Total RAM in GB: $ram"
echo "Calculated GOMAXPROCS: $gomaxprocs"

# Check if Environment=GOMAXPROCS exists in the service file
if grep -q "^Environment=GOMAXPROCS=" /lib/systemd/system/ceremonyclient.service; then
  # Update the existing line
  sudo sed -i "/^Environment=GOMAXPROCS=/c\Environment=GOMAXPROCS=$gomaxprocs" /lib/systemd/system/ceremonyclient.service
else
  # Add the Environment=GOMAXPROCS line to the [Service] section
  sudo sed -i "/\[Service\]/a Environment=GOMAXPROCS=$gomaxprocs" /lib/systemd/system/ceremonyclient.service
fi

# Reload systemd configuration
sudo systemctl daemon-reload

# Restart the service
sudo systemctl restart ceremonyclient.service
