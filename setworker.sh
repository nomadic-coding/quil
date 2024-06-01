#!/bin/bash

# Remove the specific GOMAXPROCS line from the [Install] section
sed -i '/^\[Install\]/,/^\[/{/Environment=GOMAXPROCS=2/d;}' /lib/systemd/system/ceremonyclient.service

# Get the number of CPU cores
cores=$(nproc)

# Get the total RAM in gigabytes using /proc/meminfo
ram_kb=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
ram=$((ram_kb / 1024 / 1024))  # Convert from KB to GB

# Calculate GOMAXPROCS
# Set max_cores to 40% of the total cores or the number of potential GOMAXPROCS based on available RAM, whichever is lower
required_ram_per_core=2
max_cores_by_ram=$((ram / required_ram_per_core))
max_cores_by_cores=$(awk "BEGIN {print int($cores * 0.5)}")
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
