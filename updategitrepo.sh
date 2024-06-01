#!/bin/bash

# Navigate to the repository directory
cd /root/ceremonyclient/node || { echo "Directory not found"; exit 1; }

echo "stop running service"
kill -9 $(pgrep node-1.4.18) && service ceremonyclient stop

# Stash any local changes
git reset --hard

# Set the new origin URL
git remote set-url origin https://source.quilibrium.com/quilibrium/ceremonyclient.git

# Fetch the branches from the new origin
git fetch origin

# Reset the local 'release' branch to match the remote 'release' branch
git checkout release
git reset --hard origin/release
git pull origin release
echo "Local repository reset and synced with the 'release' branch of the new remote successfully."

echo "stop running start"
service ceremonyclient start
