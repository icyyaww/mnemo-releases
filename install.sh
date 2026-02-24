#!/bin/bash
# Mnemo - AI Memory System for Claude Code
# One-click installation script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/icyyaww/mnemo/main/install.sh | bash
#
# Or with custom install directory:
#   curl -fsSL https://raw.githubusercontent.com/icyyaww/mnemo/main/install.sh | INSTALL_DIR=/opt/mnemo bash

set -e

# Configuration
REPO="icyyaww/mnemo-releases"  # 公开的 Release 仓库
VERSION="${MNEMO_VERSION:-latest}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.mnemo}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    info "Detected platform: $PLATFORM"
}

# Check dependencies
check_dependencies() {
    info "Checking dependencies..."

    # Required: curl
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed"
    fi

    # Required: Python 3
    if ! command -v python3 &> /dev/null; then
        error "Python 3 is required but not installed"
    fi

    # Required: Node.js
    if ! command -v node &> /dev/null; then
        warn "Node.js not found. Installing..."
        install_nodejs
    fi

    # Optional: Ollama (will install if not present)
    if ! command -v ollama &> /dev/null; then
        warn "Ollama not found. Installing..."
        install_ollama
    fi

    success "All dependencies satisfied"
}

# Install Node.js if not present
install_nodejs() {
    if command -v apt-get &> /dev/null; then
        sudo apt-get update && sudo apt-get install -y nodejs npm
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y nodejs npm
    elif command -v brew &> /dev/null; then
        brew install node
    else
        error "Cannot install Node.js automatically. Please install manually."
    fi
}

# Install Ollama
install_ollama() {
    info "Installing Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh

    # Start Ollama service
    if command -v systemctl &> /dev/null; then
        sudo systemctl start ollama 2>/dev/null || ollama serve &
    else
        ollama serve &
    fi
    sleep 3

    # Pull embedding model
    info "Pulling embedding model (nomic-embed-text)..."
    ollama pull nomic-embed-text
    success "Ollama installed with nomic-embed-text model"
}

# Download and install Mnemo
install_mnemo() {
    info "Installing Mnemo to $INSTALL_DIR..."

    # Create directories
    mkdir -p "$INSTALL_DIR"/{bin,config,mnemo-sync,mnemo-mcp}
    mkdir -p "$BIN_DIR"

    # Resolve version
    if [ "$VERSION" = "latest" ]; then
        VERSION=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | grep '"tag_name"' | sed 's/.*"tag_name": "\(.*\)".*/\1/')
        [ -z "$VERSION" ] && error "Failed to resolve latest version"
    fi

    # Download release
    DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/mnemo-$VERSION-$PLATFORM.tar.gz"

    info "Downloading from $DOWNLOAD_URL..."
    curl -fsSL "$DOWNLOAD_URL" | tar -xz -C "$INSTALL_DIR"

    # Make binary executable
    chmod +x "$INSTALL_DIR/bin/mnemo"

    # Create symlink in PATH
    ln -sf "$INSTALL_DIR/bin/mnemo" "$BIN_DIR/mnemo"

    success "Mnemo binary installed"
}

# Install Python dependencies
install_python_deps() {
    info "Installing Python dependencies..."
    pip3 install --user -q watchdog requests openai
    success "Python dependencies installed"
}

# Install Node.js MCP server
install_mcp() {
    info "Installing MCP server..."
    cd "$INSTALL_DIR/mnemo-mcp"
    npm install --silent
    success "MCP server installed"
}

# Configure Claude Code MCP
configure_claude_mcp() {
    info "Configuring Claude Code MCP..."

    if command -v claude &> /dev/null; then
        claude mcp add mnemo -s user -- node "$INSTALL_DIR/mnemo-mcp/dist/index.js" 2>/dev/null || true
        success "MCP configured for Claude Code"
    else
        warn "Claude Code CLI not found. Configure MCP manually:"
        echo "  claude mcp add mnemo -- node $INSTALL_DIR/mnemo-mcp/dist/index.js"
    fi
}

# Create startup script
create_startup_script() {
    cat > "$INSTALL_DIR/start.sh" << 'SCRIPT'
#!/bin/bash
INSTALL_DIR="$(dirname "$0")"

echo "Starting Mnemo memory system..."

# Start Ollama if not running
if ! curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo "Starting Ollama..."
    ollama serve > /tmp/ollama.log 2>&1 &
    sleep 3
fi

# Start Mnemo server
echo "Starting Mnemo server..."
"$INSTALL_DIR/bin/mnemo" &
sleep 2

# Start sync service
echo "Starting sync service..."
EMBEDDING_PROVIDER=ollama python3 "$INSTALL_DIR/mnemo-sync/sync.py" &

echo ""
echo "Mnemo memory system started!"
echo "  - Mnemo API: http://127.0.0.1:8080"
echo "  - Stats: curl http://127.0.0.1:8080/api/v1/stats"
SCRIPT
    chmod +x "$INSTALL_DIR/start.sh"
    ln -sf "$INSTALL_DIR/start.sh" "$BIN_DIR/mnemo-start"

    cat > "$INSTALL_DIR/stop.sh" << 'SCRIPT'
#!/bin/bash
echo "Stopping Mnemo memory system..."
pkill -f "sync.py" 2>/dev/null
pkill -f "mnemo" 2>/dev/null
echo "Done."
SCRIPT
    chmod +x "$INSTALL_DIR/stop.sh"
    ln -sf "$INSTALL_DIR/stop.sh" "$BIN_DIR/mnemo-stop"

    # Create update script
    cat > "$INSTALL_DIR/update.sh" << 'SCRIPT'
#!/bin/bash
REPO="icyyaww/mnemo-releases"
exec bash <(curl -fsSL "https://raw.githubusercontent.com/$REPO/main/update.sh")
SCRIPT
    chmod +x "$INSTALL_DIR/update.sh"
    ln -sf "$INSTALL_DIR/update.sh" "$BIN_DIR/mnemo-update"

    success "Startup scripts created"
}

# Add to PATH
configure_path() {
    SHELL_RC=""
    if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
        SHELL_RC="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bashrc" ]; then
        SHELL_RC="$HOME/.bashrc"
    fi

    if [ -n "$SHELL_RC" ]; then
        if ! grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
            echo "" >> "$SHELL_RC"
            echo "# Mnemo" >> "$SHELL_RC"
            echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
            info "Added $BIN_DIR to PATH in $SHELL_RC"
        fi
    fi
}

# Print success message
print_success() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}  Mnemo installed successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo "Quick start:"
    echo "  mnemo-start    # Start memory system"
    echo "  mnemo-stop     # Stop memory system"
    echo ""
    echo "Check status:"
    echo "  curl http://127.0.0.1:8080/api/v1/stats"
    echo ""
    echo "In Claude Code (new session):"
    echo "  recall \"之前讨论的架构方案\""
    echo ""
    echo "Documentation: $INSTALL_DIR/README.md"
    echo ""
    if [ -n "$SHELL_RC" ]; then
        echo -e "${YELLOW}Run 'source $SHELL_RC' or restart terminal to update PATH${NC}"
    fi
}

# Main installation
main() {
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║  Mnemo - AI Memory for Claude Code        ║"
    echo "║  让 AI 拥有记忆                            ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""

    detect_platform
    check_dependencies
    install_mnemo
    install_python_deps
    install_mcp
    configure_claude_mcp
    create_startup_script
    configure_path
    print_success
}

main "$@"
