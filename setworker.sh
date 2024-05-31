#!/bin/bash

# Get the number of CPU cores
cores=$(nproc)

# Get the total RAM in gigabytes
ram=$(free -g | awk '/^Mem:/{print $2}')

# Calculate GOMAXPROCS
# For example, if there are 10 cores, it should set GOMAXPROCS to 8, but only if there is at least 16GB RAM
# If there is less RAM, adjust GOMAXPROCS so the ratio GOMAXPROCS:RAM is 1:2
required_ram_per_core=2
max_cores=$((cores - 2))
required_ram=$((max_cores * required_ram_per_core))

if (( ram >= required_ram )); then
  gomaxprocs=$max_cores
else
  # Calculate the maximum GOMAXPROCS based on available RAM
  gomaxprocs=$((ram / required_ram_per_core))
fi

# Ensure GOMAXPROCS is at least 1
gomaxprocs=$((gomaxprocs > 0 ? gomaxprocs : 1))

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
