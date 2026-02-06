# Mnemo - AI Memory System for Claude Code
# Windows Installation Script (PowerShell)
#
# Usage:
#   irm https://raw.githubusercontent.com/icyyaww/mnemo-releases/main/install.ps1 | iex

$ErrorActionPreference = "Stop"

# Configuration
$REPO = "icyyaww/mnemo-releases"
$VERSION = if ($env:MNEMO_VERSION) { $env:MNEMO_VERSION } else { "latest" }
$INSTALL_DIR = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { "$env:USERPROFILE\.mnemo" }

function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Blue }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red; exit 1 }

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "  Mnemo - AI Memory for Claude Code" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# Check dependencies
Write-Info "Checking dependencies..."

if (-not (Get-Command python -ErrorAction SilentlyContinue)) {
    Write-Error "Python is required but not installed. Please install Python 3 from https://python.org"
}

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Warn "Node.js not found. Please install from https://nodejs.org"
}

if (-not (Get-Command ollama -ErrorAction SilentlyContinue)) {
    Write-Warn "Ollama not found. Installing..."
    Write-Info "Please download and install Ollama from https://ollama.com/download/windows"
    Write-Info "After installing, run: ollama pull nomic-embed-text"
}

Write-Success "Dependencies check complete"

# Download and install
Write-Info "Installing Mnemo to $INSTALL_DIR..."

# Create install directory
New-Item -ItemType Directory -Force -Path $INSTALL_DIR | Out-Null

# Determine download URL
$PLATFORM = "windows-amd64"
if ($VERSION -eq "latest") {
    $DOWNLOAD_URL = "https://github.com/$REPO/releases/latest/download/mnemo-$PLATFORM.zip"
} else {
    $DOWNLOAD_URL = "https://github.com/$REPO/releases/download/$VERSION/mnemo-$VERSION-$PLATFORM.zip"
}

Write-Info "Downloading from $DOWNLOAD_URL..."

$TMP_FILE = "$env:TEMP\mnemo-$PLATFORM.zip"
Invoke-WebRequest -Uri $DOWNLOAD_URL -OutFile $TMP_FILE

Write-Info "Extracting..."
Expand-Archive -Path $TMP_FILE -DestinationPath $INSTALL_DIR -Force

# Find extracted folder and move contents
$ExtractedFolder = Get-ChildItem -Path $INSTALL_DIR -Directory | Where-Object { $_.Name -like "mnemo-*" } | Select-Object -First 1
if ($ExtractedFolder) {
    Get-ChildItem -Path $ExtractedFolder.FullName | Move-Item -Destination $INSTALL_DIR -Force
    Remove-Item -Path $ExtractedFolder.FullName -Recurse -Force
}

Remove-Item -Path $TMP_FILE -Force

Write-Success "Mnemo installed"

# Install Python dependencies
Write-Info "Installing Python dependencies..."
pip install --user -q watchdog requests openai
Write-Success "Python dependencies installed"

# Add to PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$BinPath = "$INSTALL_DIR\bin"
if ($UserPath -notlike "*$BinPath*") {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$BinPath", "User")
    Write-Info "Added $BinPath to PATH"
}

# Configure Claude Code MCP
Write-Info "Configuring Claude Code MCP..."
if (Get-Command claude -ErrorAction SilentlyContinue) {
    try {
        claude mcp add mnemo -s user -- node "$INSTALL_DIR\mnemo-mcp\dist\index.js" 2>$null
        Write-Success "MCP configured for Claude Code"
    } catch {
        Write-Warn "Could not auto-configure MCP. Configure manually:"
        Write-Host "  claude mcp add mnemo -- node $INSTALL_DIR\mnemo-mcp\dist\index.js"
    }
} else {
    Write-Warn "Claude Code CLI not found. Configure MCP manually after installing Claude Code."
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "  Mnemo installed successfully!" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Quick start:"
Write-Host "  1. Start Ollama and pull model:"
Write-Host "     ollama pull nomic-embed-text"
Write-Host ""
Write-Host "  2. Start Mnemo:"
Write-Host "     $INSTALL_DIR\start-memory.bat"
Write-Host ""
Write-Host "  3. Stop Mnemo:"
Write-Host "     $INSTALL_DIR\stop-memory.bat"
Write-Host ""
Write-Host "Restart your terminal to update PATH."
Write-Host ""
