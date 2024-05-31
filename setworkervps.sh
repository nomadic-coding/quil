#!/bin/bash

# Get the number of CPU cores
cores=$(nproc)

# Get the total RAM in gigabytes using /proc/meminfo
ram_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
ram=$((ram_kb / 1024 / 1024))  # Convert from KB to GB

# Calculate GOMAXPROCS
# For example, if there are 10 cores, it should set GOMAXPROCS to 10, but only if there is at least 20GB RAM
# If there is less RAM, adjust GOMAXPROCS so the ratio GOMAXPROCS:RAM is 1:2
required_ram_per_core=2
max_cores=$((cores))
required_ram=$((max_cores * required_ram_per_core))

if (( ram >= required_ram )); then
  gomaxprocs=$max_cores
else
  # Calculate the maximum GOMAXPROCS based on available RAM, ensuring it does not exceed max_cores
  gomaxprocs=$((ram / required_ram_per_core))
  gomaxprocs=$((gomaxprocs > max_cores ? max_cores : gomaxprocs))
fi

# Ensure GOMAXPROCS is at least 1
gomaxprocs=$((gomaxprocs > 0 ? gomaxprocs : 1))

# Calculate CPUQuota to be 50% of the total cores
cpu_quota=$(awk "BEGIN {print $cores * 100 * 0.5}")

# Print calculated values for debugging
echo "Number of CPU cores: $cores"
echo "Total RAM in GB: $ram"
echo "Calculated GOMAXPROCS: $gomaxprocs"
echo "Calculated CPUQuota: ${cpu_quota}%"

# Update or add Environment=GOMAXPROCS and CPUQuota in the service file
if grep -q "^Environment=GOMAXPROCS=" /lib/systemd/system/ceremonyclient.service; then
  sudo sed -i "/^Environment=GOMAXPROCS=/c\Environment=GOMAXPROCS=$gomaxprocs" /lib/systemd/system/ceremonyclient.service
else
  sudo sed -i "/\[Service\]/a Environment=GOMAXPROCS=$gomaxprocs" /lib/systemd/system/ceremonyclient.service
fi

if grep -q "^CPUQuota=" /lib/systemd/system/ceremonyclient.service; then
  sudo sed -i "/^CPUQuota=/c\CPUQuota=${cpu_quota}%" /lib/systemd/system/ceremonyclient.service
else
  sudo sed -i "/\[Service\]/a CPUQuota=${cpu_quota}%" /lib/systemd/system/ceremonyclient.service
fi

# Reload systemd configuration
sudo systemctl daemon-reload

# Restart the service
sudo systemctl restart ceremonyclient.service
