#!/bin/bash

# Default settings
VERBOSE=true
SILENT=false
VERSION="v2025.4-dorina-patched"
INSTALL_DIR="$HOME/.local/bin"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--verbose)
            VERBOSE=true
            SILENT=false
            shift
            ;;
        -s|--silent)
            SILENT=true
            VERBOSE=false
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        *)
            if [[ "$1" == v* ]]; then
                VERSION="$1"
                shift
            else
                echo "Unknown parameter: $1"
                echo "Usage: $0 [-v|--verbose] [-s|--silent] [--version VERSION]"
                exit 1
            fi
            ;;
    esac
done

# Logging function with silent mode
log() {
    local level="$1"
    local message="$2"
    local color_start=""
    local color_end=""
    
    # Return immediately if silent mode is enabled (except for ERROR)
    if [[ "$SILENT" == true && "$level" != "ERROR" ]]; then
        return 0
    fi
    
    if [[ -t 1 ]]; then  # If stdout is a terminal, use colors
        case "$level" in
            "INFO")  color_start="\033[0;32m" ;; # Green
            "WARN")  color_start="\033[0;33m" ;; # Yellow
            "ERROR") color_start="\033[0;31m" ;; # Red
            "DEBUG") color_start="\033[0;36m" ;; # Cyan
        esac
        color_end="\033[0m"
    fi
    
    if [[ "$level" != "DEBUG" ]] || [[ "$VERBOSE" == true ]]; then
        echo -e "${color_start}[$level] $message${color_end}"
    fi
}

# Function to get user confirmation
confirm() {
    local prompt="$1"
    local default="$2"
    
    if [[ "$SILENT" == true ]]; then
        # In silent mode, use default answer
        return $([ "$default" = "y" ] && echo 0 || echo 1)
    fi
    
    local answer
    read -p "$prompt [y/n] ($default): " answer
    
    case "${answer,,}" in
        y|yes) return 0 ;;
        n|no) return 1 ;;
        *) return $([ "$default" = "y" ] && echo 0 || echo 1) ;;
    esac
}

# POSIX-compliant check if nym-client exists in PATH
check_nym_client_exists() {
    if command -v nym-client >/dev/null 2>&1; then
        log "INFO" "nym-client is already installed at $(command -v nym-client)"
        return 0
    else
        return 1
    fi
}

# Detect system information
detect_system() {
    # Detect operating system
    case "$(uname -s)" in
        Linux*)     OS="linux";;
        Darwin*)    OS="macos";;
        CYGWIN*|MINGW*|MSYS*) OS="windows";;
        *)          OS="unknown";;
    esac
    
    # Detect architecture
    case "$(uname -m)" in
        x86_64)     ARCH="x86_64";;
        i386|i686)  ARCH="x86";;
        arm64|aarch64) ARCH="aarch64";;
        armv7*)     ARCH="arm";;
        *)          ARCH="unknown";;
    esac
    
    log "INFO" "Detected system: $OS ($ARCH)"
    [[ "$VERBOSE" == true ]] && log "DEBUG" "uname -a: $(uname -a)"
}

# Find latest version if needed
get_latest_version() {
    if [[ "$VERSION" == "latest" ]]; then
        log "INFO" "Fetching latest version information..."
        LATEST_VERSION=$(curl -s https://api.github.com/repos/nymtech/nym/releases/latest | 
                        grep '"tag_name":' | 
                        sed -E 's/.*"([^"]+)".*/\1/' | 
                        sed 's/nym-binaries-//')
        if [[ -z "$LATEST_VERSION" ]]; then
            log "ERROR" "Failed to determine latest version"
            return 1
        fi
        VERSION="$LATEST_VERSION"
    fi
    log "INFO" "Using version: $VERSION"
    return 0
}

# Download hash file and verify
verify_binary() {
    local binary="$1"
    local hash_url="https://github.com/nymtech/nym/releases/download/nym-binaries-$VERSION/hashes.json"
    local hash_file="${TEMP_DIR}/hashes.json"

    # Download hash file
    log "INFO" "Downloading hash file from $hash_url"
    if ! curl -fsSL "$hash_url" -o "$hash_file"; then
        log "WARN" "Could not download hash file for verification"
        return 0
    fi

    # Calculate hash of binary
    if command -v sha256sum >/dev/null; then
        HASH=$(sha256sum "$binary" | cut -d ' ' -f 1)
    elif command -v shasum >/dev/null; then
        HASH=$(shasum -a 256 "$binary" | cut -d ' ' -f 1)
    else
        log "WARN" "No SHA-256 utility found, skipping hash verification"
        return 0
    fi

    [[ "$VERBOSE" == true ]] && log "DEBUG" "Binary hash: $HASH"
    
    # Verify hash against json file
    if command -v jq >/dev/null; then
        # Using jq for proper JSON parsing
        FOUND=$(jq -r ".assets | .[] | .sha256" "$hash_file" | grep -F "$HASH")
        if [[ -n "$FOUND" ]]; then
            log "INFO" "Hash verification successful!"
        else
            log "ERROR" "Hash verification failed! Binary may be compromised."
            return 1
        fi
    else
        # Fallback if jq not available
        if grep -q "$HASH" "$hash_file"; then
            log "INFO" "Hash verification succeeded (basic check)"
        else
            log "WARN" "Hash not found in file. Verification cannot be completed without jq"
        fi
    fi
    return 0
}

# Download pre-compiled binary
download_binary() {
    local binary_url="https://github.com/nymtech/nym/releases/download/nym-binaries-$VERSION/nym-client"
    local output="${TEMP_DIR}/nym-client"
    
    log "INFO" "Downloading nym-client binary from GitHub..."
    if curl -fsSL "$binary_url" -o "$output"; then
        chmod +x "$output"
        verify_binary "$output"
        return 0
    else
        log "ERROR" "Failed to download binary"
        return 1
    fi
}

# Check for Rust toolchain
check_rust() {
    if ! command -v rustc >/dev/null 2>&1; then
        log "INFO" "Rust not found"
        if confirm "Do you want to install Rust?" "y"; then
            log "INFO" "Installing Rust..."
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
            source "$HOME/.cargo/env"
            log "INFO" "Rust installed successfully"
        else
            log "ERROR" "Rust is required to build nym-client from source"
            return 1
        fi
    else
        RUST_VERSION=$(rustc --version)
        log "INFO" "Rust found: $RUST_VERSION"
        if confirm "Do you want to update Rust toolchain?" "y"; then
            log "INFO" "Updating Rust toolchain..."
            rustup update
            log "INFO" "Rust updated successfully"
        fi
    fi
    return 0
}

# Build from source for non-x86 architectures
build_from_source() {
    log "INFO" "Building nym-client from source for $ARCH architecture"
    
    # Check for Rust toolchain
    if ! check_rust; then
        return 1
    fi
    
    cd "${TEMP_DIR}"
    
    # Clone repository
    log "INFO" "Cloning Nym repository..."
    git clone https://github.com/nymtech/nym.git
    cd nym
    
    # Checkout appropriate branch
    log "INFO" "Checking out master branch"
    git checkout master
    
    # Build client
    log "INFO" "Building nym-client (this will take several minutes)..."
    cargo build --release --bin nym-client
    
    if [[ -f "target/release/nym-client" ]]; then
        cp "target/release/nym-client" "${TEMP_DIR}/nym-client"
        chmod +x "${TEMP_DIR}/nym-client"
        log "INFO" "Build successful"
        return 0
    else
        log "ERROR" "Build failed"
        return 1
    fi
}

# Main installation function
install_nym_client() {
    # Check if nym-client already exists
    if check_nym_client_exists; then
        if ! confirm "nym-client is already installed. Install anyway?" "n"; then
            log "INFO" "Installation cancelled"
            exit 0
        fi
    fi
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    log "INFO" "Starting nym-client installation"
    
    # Get system information
    detect_system
    get_latest_version || exit 1
    
    # Install based on architecture
    if [[ "$ARCH" == "x86_64" || "$ARCH" == "x86" ]]; then
        log "INFO" "Using pre-compiled binary for $ARCH"
        download_binary || exit 1
    else
        log "INFO" "Architecture $ARCH requires building from source"
        build_from_source || exit 1
    fi
    
    # Create installation directory
    mkdir -p "$INSTALL_DIR"
    
    # Install binary
    cp "${TEMP_DIR}/nym-client" "${INSTALL_DIR}/nym-client"
    log "INFO" "Installed nym-client to ${INSTALL_DIR}/nym-client"
    
    # Check if installation directory is in PATH
    if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
        log "WARN" "${INSTALL_DIR} is not in your PATH"
        log "INFO" "Add to your PATH with: export PATH=\"${INSTALL_DIR}:\$PATH\""
    fi
    
    # Verify installation
    if "${INSTALL_DIR}/nym-client" --version >/dev/null 2>&1; then
        CLIENT_VERSION=$("${INSTALL_DIR}/nym-client" --version | head -n 1)
        log "INFO" "Installation successful: $CLIENT_VERSION"
    else
        log "ERROR" "Installation verification failed"
        exit 1
    fi
    
    # Show usage information
    log "INFO" "To initialize a client: ${INSTALL_DIR}/nym-client init --id YOUR_CLIENT_ID"
    log "INFO" "To run a client: ${INSTALL_DIR}/nym-client run --id YOUR_CLIENT_ID"
}

# Run the installation
install_nym_client
