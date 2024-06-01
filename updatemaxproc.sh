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

# Function to ensure GOMAXPROCS is only in the [Service] section
move_gomaxprocs_to_service() {
  local file=$1
  local gomaxprocs_line="Environment=GOMAXPROCS=$gomaxprocs"
  local in_service_section=false
  local in_install_section=false
  local new_content=""
  local gomaxprocs_added=false

  while IFS= read -r line; do
    if [[ $line =~ ^\[(.*)\]$ ]]; then
      current_section="${BASH_REMATCH[1]}"
    fi

    if [[ $current_section == "Service" ]]; then
      in_service_section=true
      in_install_section=false
    elif [[ $current_section == "Install" ]]; then
      in_install_section=true
      in_service_section=false
    else
      in_service_section=false
      in_install_section=false
    fi

    # Remove any existing GOMAXPROCS line
    if [[ $line == Environment=GOMAXPROCS=* ]]; then
      continue
    fi

    new_content+="$line"$'\n'

    # If we are in the Service section, add the GOMAXPROCS line once
    if $in_service_section && ! $gomaxprocs_added; then
      new_content+="$gomaxprocs_line"$'\n'
      gomaxprocs_added=true
    fi
  done < "$file"

  echo "$new_content" > "$file"
}

# Call the function to update the service file
move_gomaxprocs_to_service "$service_file"

# Remove CPUQuota= line if it exists
sed -i "/^CPUQuota=/d" "$service_file"

# Reload the systemd manager configuration
systemctl daemon-reload

# Restart the service to apply changes
systemctl restart ceremonyclient.service

echo "GOMAXPROCS has been updated to $gomaxprocs in $service_file, CPUQuota= has been removed (if it existed), and the service has been restarted."
