#!/bin/bash

# Path to the directory to check for updates
REPO_PATH="/root/ceremonyclient/node"

# Name of the service to stop if an update is found
SERVICE_NAME="ceremonyclient"

# Path to the service configuration file
SERVICE_CONFIG_PATH="/lib/systemd/system/ceremonyclient.service"

# The branch to check for updates
BRANCH="release"

# Function to check for updates and handle the service accordingly
check_for_updates() {
    cd $REPO_PATH
    
    # Ensure we are on the release branch and discard any local changes
    echo "Switching to the $BRANCH branch and discarding local changes"
    git fetch
    git reset --hard origin/$BRANCH
    git checkout --force $BRANCH

    # Check if the local branch is behind the remote branch
    if git fetch && git status | grep -q "Your branch is behind"; then
        echo "Updates found. Pulling the latest changes..."
        
        echo "Stopping the service: $SERVICE_NAME"
        # Stop the service
        systemctl stop $SERVICE_NAME
        
        # Discard any local changes
        git reset --hard origin/$BRANCH
        
        # Pull the latest updates
        git pull
        
        # Find the most recent node binary ending with -linux-amd64 in the REPO_PATH
        LATEST_BINARY=$(ls -t $REPO_PATH/node-*-linux-amd64 | head -n 1)
        
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
}

# Perform the update check
check_for_updates
echo "Check complete."
