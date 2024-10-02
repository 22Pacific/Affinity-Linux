#!/bin/bash

# Set strict mode
set -euo pipefail

# Function to log messages with levels
log() {
    local level="$1"
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $@"
}

# Function to check dependencies
check_dependencies() {
    local deps=("wine" "winetricks" "wget" "curl" "7z" "tar" "unzip" "jq")
    local missing_deps=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        log "ERROR" "Missing dependencies: ${missing_deps[*]}"
        log "ERROR" "Please install them and rerun the script."
        exit 1
    fi
    log "INFO" "All dependencies are installed!"
}

# Function to safely create directory
create_directory() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || { log "ERROR" "Failed to create directory $dir"; exit 1; }
    fi
}

# Function to download file with progress bar and verification
download_file() {
    local url="$1"
    local output="$2"
    local description="$3"

    log "INFO" "Downloading $description..."
    if ! wget --show-progress -q "$url" -O "$output"; then
        log "ERROR" "Failed to download $description"
        return 1
    fi
    return 0
}

# Function to clean up temporary files in case of error or exit
cleanup() {
    log "INFO" "Cleaning up temporary files..."
    rm -f "$directory/$filename"
    rm -f "$directory/Winmetadata.zip"
}
trap cleanup EXIT  # Cleanup will always run when the script exits

# Main script execution
main() {
    # Configuration: Using a timestamp-based directory for better organization
    local directory="$HOME/.AffinityLinux"
    local repo="22Pacific/ElementalWarrior-wine-binaries"
    local filename="ElementalWarriorWine.zip"

    # Check dependencies
    check_dependencies

    # Kill wine processes
    wineserver -k || log "WARNING" "No wine processes were running"

    # Create install directory
    create_directory "$directory"

    # Fetch latest release information
    log "INFO" "Fetching release information..."
    local release_info
    release_info=$(curl -s "https://api.github.com/repos/$repo/releases/latest") || { log "ERROR" "Failed to fetch release info"; exit 1; }
    local download_url
    download_url=$(echo "$release_info" | jq -r ".assets[] | select(.name == \"$filename\") | .browser_download_url")

    if [ -z "$download_url" ]; then
        log "ERROR" "File not found in the latest release"
        exit 1
    fi

    # Download and verify wine binaries
    download_file "$download_url" "$directory/$filename" "wine binaries"

    # Verify file size
    local github_size
    github_size=$(echo "$release_info" | jq -r ".assets[] | select(.name == \"$filename\") | .size")
    local local_size
    local_size=$(wc -c < "$directory/$filename")

    if [ "$github_size" -ne "$local_size" ]; then
        log "WARNING" "File size mismatch. Expected: $github_size, Got: $local_size"
        log "INFO" "Please download $filename manually from $download_url"
        exit 1
    fi

    # Download WinMetadata
    download_file "https://archive.org/download/win-metadata/WinMetadata.zip" \
                  "$directory/Winmetadata.zip" \
                  "WinMetadata"

    # Extract files with progress bar
    log "INFO" "Extracting files..."
    unzip -q "$directory/$filename" -d "$directory"
    rm "$directory/$filename"

    # Extract WinMetadata
    7z x "$directory/Winmetadata.zip" -o"$directory/drive_c/windows/system32" | pv -l > /dev/null
    rm "$directory/Winmetadata.zip"

    # WINETRICKS setup - running non-interactively
    log "INFO" "Configuring Wine environment..."
    WINEPREFIX="$directory" winetricks --unattended --force dotnet35 dotnet48 corefonts
    WINEPREFIX="$directory" winetricks renderer=vulkan

    # Set Windows version
    WINEPREFIX="$directory" "$directory/ElementalWarriorWine/bin/winecfg" -v win11


    log "INFO" "Setup completed successfully!"
}

# Run main function
main "$@"
