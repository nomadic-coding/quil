#!/bin/bash

# Path to the directory to check for updates
REPO_PATH="/root/ceremonyclient/node"

# Name of the service to stop if an update is found
SERVICE_NAME="ceremonyclient"

# Path to the service configuration file
SERVICE_CONFIG_PATH="/lib/systemd/system/ceremonyclient.service"

# The correct remote URL for the binary
BINARY_URL="https://releases.quilibrium.com/release"

# Fetch the binary from the specified URL
fetch() {
    release_os="linux"
    release_arch="amd64"
    files=$(curl -s $BINARY_URL | grep $release_os-$release_arch)
    new_release=false

    for file in $files; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if ! test -f "./$file"; then
            echo "Downloading new release: $file"
            curl -s "https://releases.quilibrium.com/$file" -o "$file"
            chmod +x "$file"
            new_release=true
        fi
    done
    echo $new_release
}

cd $REPO_PATH

# Fetch the latest binary
new_release=$(fetch)

# Extract the current ExecStart binary path from the service configuration file
CURRENT_BINARY=$(grep "^ExecStart=" $SERVICE_CONFIG_PATH | cut -d'=' -f2)

# Find the most recent node binary ending with -linux-amd64 in the REPO_PATH
LATEST_BINARY=$(ls -t $REPO_PATH/node-*-linux-amd64 | head -n 1)

if [ "$new_release" = "true" ] || [ "$LATEST_BINARY" != "$CURRENT_BINARY" ]; then
    if [[ -x "$LATEST_BINARY" ]]; then
        echo "Updating service configuration with the latest binary: $LATEST_BINARY"
        
        # Update the service configuration file with the new binary path
        sed -i "s|ExecStart=.*|ExecStart=$LATEST_BINARY|" $SERVICE_CONFIG_PATH
        
        echo "Reloading systemd manager configuration..."
        systemctl daemon-reload
        
        echo "Restarting the service: $SERVICE_NAME"
        systemctl restart $SERVICE_NAME
    else
        echo "Error: No valid binary found in the repository. The service will not be restarted."
    fi
else
    echo "No updates found. The repository is up to date."
fi

echo "Check complete."
