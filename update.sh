#!/bin/bash

# Path to the directory to check for updates
REPO_PATH="/root/ceremonyclient/node"
CLIENT_PATH="/root/ceremonyclient/client"

# Name of the service to stop if an update is found
SERVICE_NAME="ceremonyclient"

# The correct remote URL for the binary
BINARY_URL="https://releases.quilibrium.com/release"
CLIENT_URL="https://releases.quilibrium.com/qclient-release"

# Fetch the binary from the specified URL
fetch() {
    release_os="linux"
    release_arch="amd64"
    new_node_release=false
    new_client_release=false

    # Check for new node version
    files=$(curl -s $BINARY_URL | grep $release_os-$release_arch)
    for file in $files; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if ! test -f "$REPO_PATH/$file"; then
            echo "Downloading new release: $file"
            curl -s "https://releases.quilibrium.com/$file" -o "$REPO_PATH/$file"
            chmod +x "$REPO_PATH/$file"
            new_node_release=true
        fi
    done
    echo $new_node_release

    # Check for new client version
    client_files=$(curl -s $CLIENT_URL | grep $release_os-$release_arch)
    for file in $client_files; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if ! test -f "$CLIENT_PATH/$file"; then
            echo "Downloading new client release: $file"
            curl -s "https://releases.quilibrium.com/$file" -o "$CLIENT_PATH/$file"
            chmod +x "$CLIENT_PATH/$file"
            new_client_release=true
        fi
    done

    echo "$new_node_release $new_client_release"
}

cd $REPO_PATH

# Fetch the latest binary
read new_node_release new_client_release <<< $(fetch)

# Find the most recent node binary ending with -linux-amd64 in the REPO_PATH
LATEST_BINARY=$(ls -t $REPO_PATH/node-*-linux-amd64 | head -n 1)

# Check if active-node symlink exists, if not create it
if [ ! -L "$REPO_PATH/active-node" ]; then
    echo "Creating active-node symlink"
    ln -s "$LATEST_BINARY" "$REPO_PATH/active-node"
fi

if [ "$new_node_release" = "true" ] || [ "$(readlink -f $REPO_PATH/active-node)" != "$LATEST_BINARY" ]; then
    if [[ -x "$LATEST_BINARY" ]]; then
        echo "Updating symlink with the latest binary: $LATEST_BINARY"
        
        # Update the symlink to point to the new binary
        ln -sf "$LATEST_BINARY" "$REPO_PATH/active-node"
        
        echo "Restarting the service: $SERVICE_NAME"
        systemctl restart $SERVICE_NAME
    else
        echo "Error: No valid binary found in the repository. The service will not be restarted."
    fi
else
    echo "No updates found. The repository is up to date."
fi

echo "Check complete."
