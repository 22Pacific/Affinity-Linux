#!/bin/bash

# Check for required dependencies
missing_deps=""

check_dependency() {
  if ! command -v "$1" &> /dev/null; then
    missing_deps+="$1 "
  fi
}

check_dependency "wine"
check_dependency "winetricks"
check_dependency "wget"
check_dependency "curl"
check_dependency "7z"
check_dependency "tar"
check_dependency "unzip" # Added unzip for .zip file extraction

if [ -n "$missing_deps" ]; then
  echo "The following dependencies are missing: $missing_deps"
  echo "Please install them and rerun the script."
  exit 1
fi

echo "All dependencies are installed!"
sleep 2

directory="$HOME/.AffinityLinux"
repo="22Pacific/ElementalWarrior-wine-binaries" #Owner/Repo
filename="ElementalWarriorWine.zip" #Filename

# Kill wine processes
wineserver -k

# Create install directory if it doesn't exist
mkdir -p "$directory"

# Fetch the latest release information from GitHub
release_info=$(curl -s "https://api.github.com/repos/$repo/releases/latest")
download_url=$(echo "$release_info" | jq -r ".assets[] | select(.name == \"$filename\") | .browser_download_url")
[ -z "$download_url" ] && { echo "File not found in the latest release"; exit 1; }

# Download the specific release asset
wget -q "$download_url" -O "$directory/$filename" # Download wine binaries

# Check if the downloaded file size matches GitHub's reported size
github_size=$(echo "$release_info" | jq -r ".assets[] | select(.name == \"$filename\") | .size")
local_size=$(wc -c < "$directory/$filename")

if [ "$github_size" -eq "$local_size" ]; then
    echo "File sizes match: $local_size bytes"
else
    echo "File sizes do not match: GitHub size: $github_size bytes, Local size: $local_size bytes"
    echo "Please download $filename manually from $download_url and move it to $directory, then press any key to continue."
    read -n 1
fi

# Download additional files (with error checking)
if ! wget https://upload.wikimedia.org/wikipedia/commons/3/3c/Affinity_Designer_2-logo.svg -O "/home/$USER/.local/share/icons/AffinityDesigner.svg"; then
  echo "Failed to download Affinity Designer logo."
  exit 1
fi

if ! wget https://archive.org/download/win-metadata/WinMetadata.zip -O "$directory/Winmetadata.zip"; then
  echo "Failed to download WinMetadata.zip."
  exit 1
fi

# Extract the wine binary (.zip file)
unzip "$directory/$filename" -d "$directory"

# Remove the original .zip file after extraction
rm "$directory/$filename"

# WINETRICKS setup
WINEPREFIX="$directory" winetricks --unattended dotnet35 dotnet48 corefonts
WINEPREFIX="$directory" winetricks renderer=vulkan

#Set windows version to 11
WINEPREFIX="$directory" "$directory/ElementalWarriorWine/bin/winecfg" -v win11

# Extract & delete WinMetadata.zip
7z x "$directory/Winmetadata.zip" -o"$directory/drive_c/windows/system32"
rm "$directory/Winmetadata.zip"

#Wine dark theme
wget https://raw.githubusercontent.com/Twig6943/AffinityOnLinux/main/wine-dark-theme.reg -O "$directory/wine-dark-theme.reg"
WINEPREFIX="$directory" "$directory/ElementalWarriorWine/bin/regedit" "$directory/wine-dark-theme.reg"
rm "$directory/wine-dark-theme.reg"
