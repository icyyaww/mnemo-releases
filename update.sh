#!/bin/bash
# Mnemo - AI Memory System for Claude Code
# Lightweight update script (binary + MCP server only)
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/icyyaww/mnemo-releases/main/update.sh | bash
#
# Or update to a specific version:
#   curl -fsSL https://raw.githubusercontent.com/icyyaww/mnemo-releases/main/update.sh | MNEMO_VERSION=v0.1.1 bash

set -e

# Configuration
REPO="icyyaww/mnemo-releases"
VERSION="${MNEMO_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.mnemo}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "$OS" in
        linux)  OS="linux" ;;
        darwin) OS="darwin" ;;
        *)      error "Unsupported OS: $OS" ;;
    esac

    case "$ARCH" in
        x86_64|amd64)  ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *)             error "Unsupported architecture: $ARCH" ;;
    esac

    PLATFORM="${OS}-${ARCH}"
}

# Get current installed version
get_current_version() {
    if [ -x "$INSTALL_DIR/bin/mnemo" ]; then
        CURRENT=$("$INSTALL_DIR/bin/mnemo" --version 2>/dev/null || echo "unknown")
    else
        CURRENT="not installed"
    fi
}

main() {
    echo ""
    echo -e "${BLUE}Mnemo Updater${NC}"
    echo ""

    detect_platform
    get_current_version
    info "Current version: $CURRENT"

    # Resolve latest version
    if [ "$VERSION" = "latest" ]; then
        VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
        [ -z "$VERSION" ] && error "Failed to resolve latest version"
    fi
    info "Target version:  $VERSION"

    # Check install directory
    [ -d "$INSTALL_DIR" ] || error "Mnemo not installed at $INSTALL_DIR. Run install.sh first."

    # Stop running services
    if pgrep -f "$INSTALL_DIR/bin/mnemo" > /dev/null 2>&1; then
        warn "Stopping running Mnemo service..."
        pkill -f "$INSTALL_DIR/bin/mnemo" 2>/dev/null || true
        sleep 1
    fi

    # Download new release
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/mnemo-$VERSION-$PLATFORM.tar.gz"
    info "Downloading $VERSION for $PLATFORM..."

    TMP_DIR=$(mktemp -d)
    curl -fsSL "$DOWNLOAD_URL" | tar -xz -C "$TMP_DIR"

    # Find extracted directory
    EXTRACTED=$(find "$TMP_DIR" -maxdepth 1 -type d -name "mnemo-*" | head -1)
    [ -z "$EXTRACTED" ] && EXTRACTED="$TMP_DIR"

    # Update binary
    if [ -f "$EXTRACTED/bin/mnemo" ]; then
        cp "$EXTRACTED/bin/mnemo" "$INSTALL_DIR/bin/mnemo"
        chmod +x "$INSTALL_DIR/bin/mnemo"
        success "Binary updated"
    else
        error "Binary not found in release package"
    fi

    # Update MCP server
    if [ -d "$EXTRACTED/mnemo-mcp" ]; then
        rm -rf "$INSTALL_DIR/mnemo-mcp/dist" "$INSTALL_DIR/mnemo-mcp/node_modules"
        cp -r "$EXTRACTED/mnemo-mcp/dist" "$INSTALL_DIR/mnemo-mcp/"
        cp "$EXTRACTED/mnemo-mcp/package.json" "$INSTALL_DIR/mnemo-mcp/"
        [ -d "$EXTRACTED/mnemo-mcp/node_modules" ] && cp -r "$EXTRACTED/mnemo-mcp/node_modules" "$INSTALL_DIR/mnemo-mcp/"
        success "MCP server updated"
    fi

    # Update sync scripts
    if [ -d "$EXTRACTED/mnemo-sync" ]; then
        cp "$EXTRACTED/mnemo-sync/"*.py "$INSTALL_DIR/mnemo-sync/"
        success "Sync scripts updated"
    fi

    # Cleanup
    rm -rf "$TMP_DIR"

    echo ""
    echo -e "${GREEN}Updated to $VERSION${NC}"
    echo ""
    echo "Run 'mnemo-start' to restart the service."
    echo ""
}

main "$@"
