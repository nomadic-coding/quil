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

# Step 1: Create Ceremonyclient Service
echo "Creating Ceremonyclient Service..."
sleep 1  # Add a 1-second delay

# Define the service file path
SERVICE_FILE="/lib/systemd/system/ceremonyclient.service"

sudo tee $SERVICE_FILE > /dev/null <<EOF
[Unit]
Description=Ceremony Client Go App Service
After=network.target
Wants=network-online.target
StartLimitIntervalSec=0

[Service]
Type=simple
WorkingDirectory=/root/ceremonyclient/node/
Restart=on-failure
RestartSec=5
StartLimitBurst=5
User=root
ExecStart=/root/ceremonyclient/node/active-node
ExecStop=/bin/kill -s SIGINT \$MAINPID
ExecReload=/bin/kill -s SIGINT \$MAINPID && /root/ceremonyclient/node/active-node
KillSignal=SIGINT
RestartKillSignal=SIGINT
FinalKillSignal=SIGKILL
TimeoutStopSec=30
PIDFile=/var/run/ceremonyclient.pid

[Install]
WantedBy=multi-user.target
EOF

# Step 2: Create symlink if not already exist
echo "Checking for the latest node file (node-*-linux-amd64) and creating symlink..."
sleep 1  # Add a 1-second delay

# Define the directory and symlink paths
NODE_DIR="/root/ceremonyclient/node/"
SYMLINK="$NODE_DIR/active-node"

# Find the newest node-* file ending with -linux-amd64
NEWEST_NODE_FILE=$(ls -t $NODE_DIR/node-*-linux-amd64 2>/dev/null | head -n 1)

if [[ -z "$NEWEST_NODE_FILE" ]]; then
    echo "Error: No file matching node-*-linux-amd64 found in $NODE_DIR."
    exit 1
fi

# Check if the symlink already exists and points to the correct file
if [[ -L "$SYMLINK" && "$(readlink "$SYMLINK")" == "$NEWEST_NODE_FILE" ]]; then
    echo "Symlink already exists and is up to date: $SYMLINK -> $NEWEST_NODE_FILE"
else
    echo "Creating/Updating symlink: $SYMLINK -> $NEWEST_NODE_FILE"
    ln -sf "$NEWEST_NODE_FILE" "$SYMLINK"
fi

# Step 3: Reload systemd manager configuration
echo "Reloading systemd manager configuration..."
sudo systemctl daemon-reload

# Step 4: Enable and start the ceremonyclient service
echo "Enabling and starting Ceremonyclient Service..."
sleep 1  # Add a 1-second delay
sudo systemctl enable ceremonyclient
sudo systemctl start ceremonyclient

# Step 5: Final messages
echo "Now your node is running as a service!"
