#!/bin/bash

# Exit on any error
set -e

# Define a function for displaying exit messages
exit_message() {
    echo "There was an error during the script execution and the process stopped. No worries!"
    echo "You can try to run the script from scratch again."
    echo "If you still receive an error, you may want to proceed manually, step by step instead of using the auto-installer."
}

# Set a trap to call exit_message on any error
trap exit_message ERR

# Step 0: Welcome
echo "This script will install your Quilibrium node as a service and start it."
echo "Made with 🔥 by LaMat"
echo "Processing..."
sleep 7  # Add a 7-second delay

# Create Ceremonyclient Service
echo "Creating Ceremonyclient Service"
sleep 1  # Add a 1-second delay
sudo tee /lib/systemd/system/ceremonyclient.service > /dev/null <<EOF
[Unit]
Description=Ceremony Client Go App Service

[Service]
Type=simple
Restart=always
RestartSec=5s
WorkingDirectory=/root/ceremonyclient/node
Environment=GOEXPERIMENT=arenas
ExecStart=/root/ceremonyclient/node/node-1.4.19-linux-amd64

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd manager configuration
sudo systemctl daemon-reload

# Start the ceremonyclient service
echo "Starting Ceremonyclient Service"
sleep 1  # Add a 1-second delay
sudo systemctl enable ceremonyclient
sudo systemctl start ceremonyclient

# Final messages
echo "Now your node is running as a service!"
