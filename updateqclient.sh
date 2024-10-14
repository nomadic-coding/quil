#!/bin/bash

REPO_PATH="/root/ceremonyclient/client"
BINARY_URL="https://releases.quilibrium.com/qclient-release"
RELEASE_OS="linux"
RELEASE_ARCH="amd64"

fetch_and_update() {
    local new_release=false
    # Match binary, signature, and all dgst.sig files
    local files=$(curl -s $BINARY_URL | grep -E "qclient-[0-9.]+-$RELEASE_OS-$RELEASE_ARCH($|\.sig|\.dgst\.sig\.)")

    if [ -z "$files" ]; then
        echo "Error: No files matching $RELEASE_OS-$RELEASE_ARCH found at $BINARY_URL"
        return 1
    fi

    for file in $files; do
        if [ ! -f "$REPO_PATH/$file" ]; then
            echo "Downloading file: $file"
            curl -s "$BINARY_URL/$file" -o "$REPO_PATH/$file"
            if [ $? -eq 0 ]; then
                # Only set executable permission for binary files
                if [[ ! $file =~ \.(sig|dgst\.sig\.) ]]; then
                    chmod +x "$REPO_PATH/$file"
                fi
                new_release=true
            else
                echo "Error: Failed to download $file"
                return 1
            fi
        fi
    done

    # Remove old files except the newly downloaded ones
    find "$REPO_PATH" -name "qclient-*-$RELEASE_OS-$RELEASE_ARCH*" -type f | while read old_file; do
        if ! echo "$files" | grep -q "$(basename "$old_file")"; then
            rm "$old_file"
        fi
    done

    return $([ "$new_release" = true ] && echo 0 || echo 1)
}

cd $REPO_PATH

fetch_and_update
new_release=$?

if [ $new_release -eq 0 ]; then
     echo "Update done"
else
    echo "No updates found. The repository is up to date."
fi

echo "Check complete."
