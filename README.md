# Nym-Build

A simple and efficient way to install the Nym client on any platform with just a single command.

## Overview

The Nym-Build script automates the installation of the [Nym client](https://nymtech.net/) on various platforms and architectures. It detects your system configuration and either:

- Downloads pre-compiled binaries for x86_64 systems
- Builds from source for other architectures (ARM, aarch64, etc.)

All installations are verified with cryptographic hashes to ensure integrity and security.

## Prerequisites

- **Bash** - The script runs in a bash shell
- **curl** - Required for downloading files
- For binary installation (x86_64):
  - No additional requirements
- For source compilation (non-x86_64):
  - Git
  - Internet connection
  - Approximately 2GB free disk space for the build process

## Quick Install

Install the latest Nym client with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/dial0ut/nym-build/main/nym_build.sh | bash
```

## Usage Options

### Basic Installation

```bash
# Install latest version
curl -fsSL https://raw.githubusercontent.com/dial0ut/nym-build/main/nym_build.sh | bash

# Install with verbose output
curl -fsSL https://raw.githubusercontent.com/dial0ut/nym-build/main/nym_build.sh | bash -s -- -v

# Install specific version
curl -fsSL https://raw.githubusercontent.com/dial0ut/nym-build/main/nym_build.sh | bash -s -- --version v2025.4-dorina-patched
```

### Download and Run Locally

```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/dial0ut/nym-build/main/nym_build.sh -o nym_build.sh
chmod +x nym_build.sh

# Run with options
./nym_build.sh -v
```

## Command-line Options

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose output for detailed information |
| `--version VERSION` | Specify Nym client version to install (e.g., `v2025.4-dorina-patched`) |

## Installation Details

The script:

1. Detects your operating system and architecture
2. Downloads the latest version information (or uses specified version)
3. For x86_64: Downloads pre-compiled binary
4. For other architectures: Builds from source using Rust
5. Verifies the binary hash for security
6. Installs to `~/.local/bin` (no sudo required)
7. Provides usage instructions

## After Installation

Once installed, you can initialize and run the Nym client:

```bash
# Initialize a new client
~/.local/bin/nym-client init --id YOUR_CLIENT_ID

# Run your client
~/.local/bin/nym-client run --id YOUR_CLIENT_ID
```

Make sure that `~/.local/bin` is in your PATH. If it's not, add the following to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Troubleshooting

### Common Issues

- **"Command not found" after installation**: Ensure `~/.local/bin` is in your PATH.
- **Build failure on ARM/aarch64**: Ensure you have sufficient disk space and RAM for compilation.
- **Hash verification failure**: This could indicate a compromised binary. Try again or report the issue.

### Logs

When using the `-v` flag, detailed logs are displayed to help diagnose any issues.

## Security

The script verifies binary integrity by comparing with the official hashes published by the Nym team. It doesn't require or use sudo privileges, installing only to user-accessible directories.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request or open an Issue on the GitHub repository.

## License

MIT License - See [LICENSE](LICENSE) for details.

