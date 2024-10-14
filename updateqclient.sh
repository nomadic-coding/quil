#!/bin/bash

REPO_PATH="/root/ceremonyclient/client"
BINARY_URL="https://releases.quilibrium.com/qclient-release"

# Fetch the binary from the specified URL
fetch() {
    release_os="linux"
    release_arch="amd64"
    files=$(curl -s $BINARY_URL | grep $release_os-$release_arch)
    new_release=false

    for file in $files; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if ! test -f "$REPO_PATH/$file"; then
            echo "Downloading new release: $file"
            curl -s "https://releases.quilibrium.com/$file" -o "$REPO_PATH/$file"
            chmod +x "$REPO_PATH/$file"
            new_release=true
        fi
    done
    echo $new_release
}

cd $REPO_PATH

new_release=$(fetch)

if [ "$new_release" = "true" ]; then
     echo "Update done"
else
    echo "No updates found. The repository is up to date."
fi

echo "Check complete."
