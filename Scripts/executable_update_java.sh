#!/bin/bash

# Ensure there is a valid SDKMAN installation
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]] && source "$SDKMAN_DIR/bin/sdkman-init.sh"

echo "🔄 Updating SDKMAN candidate index..."
sdk update

# Identify locally installed Java versions
installed_versions=($(ls -1 "$SDKMAN_DIR/candidates/java" 2>/dev/null | grep -v "current"))

if [ ${#installed_versions[@]} -eq 0 ]; then
    echo "❌ No SDKMAN-managed Java installations found."
    exit 1
fi

echo "📋 Found ${#installed_versions[@]} local Java version(s)."

# Identify what 'current' is pointing to (resolves the symlink to get the folder name)
current_default=""
if [ -L "$SDKMAN_DIR/candidates/java/current" ]; then
    current_default=$(basename "$(readlink "$SDKMAN_DIR/candidates/java/current")")
    echo "⭐ Current shell default is set to: $current_default"
fi

# Determine which newer versions are available for the currently installed versions
echo "📡 Searching for newer available versions"
export SDKMAN_NO_COLOUR="true"
REMOTE_MATRIX=$(PAGER=cat sdk list java < /dev/null)

# 4. Iterate over each local installation to check for updates
for local_ver in "${installed_versions[@]}"; do
    echo "--------------------------------------------------"
    echo "🔍 Checking: $local_ver"
    
    # Extract the vendor suffix (e.g., 'tem', 'amzn', 'zulu')
    vendor="${local_ver##*-}"
    
    # Extract the base major version number
    if [[ "$local_ver" =~ ^([0-9]+) ]]; then
        major_ver="${BASH_REMATCH}"
    else
        echo "⚠️ Could not parse major version number for $local_ver. Skipping..."
        continue
    fi
    
    # Parse out the absolute newest remote version matching the same major line and vendor suffix
    latest_remote=$(echo "$REMOTE_MATRIX" | grep -E "\|" | awk -F '|' '{print $NF}' | tr -d '[:blank:]' | grep -E "^${major_ver}\..*-${vendor}$" | sort -V | tail -n 1)

    if [ -z "$latest_remote" ]; then
        echo "⚠️ Remote version matching '${major_ver}.x.x-${vendor}' was not found. Skipping..."
        continue
    fi

    echo "💡 Latest remote version: $latest_remote"

    # 5. Evaluate and perform upgrade
    if [ "$local_ver" != "$latest_remote" ]; then
        echo "🚀 Upgrade available! Installing $latest_remote..."
        sdk install java "$latest_remote"

        # Check if the version we are about to delete is our active shell default
        if [ "$local_ver" == "$current_default" ]; then
            echo "🔄 $local_ver was the active default. Updating default to $latest_remote..."
            sdk default java "$latest_remote"
            # Update local script state variable in case future loops need to know
            current_default="$latest_remote"
        fi

        # Remove the previous version
        echo "🗑️ Removing outdated version $local_ver..."
        sdk uninstall java "$local_ver"
    else
        echo "✅ $local_ver is already on the latest available version."
    fi
done

echo "--------------------------------------------------"
echo "🧹 Cleaning old downloads"
sdk flush archives
echo
echo "--------------------------------------------------"
echo "🎉 All Java versions are now up to date!"

