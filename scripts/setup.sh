#!/bin/bash
# utts Setup Script (Tier 2 - Piper Installation)
# Installs Python venv, piper-tts, SoX, and minimal voices
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTTS_DIR="$(dirname "$SCRIPT_DIR")"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║              utts Setup (Tier 2 - Piper)                  ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "UTTS_DIR: $UTTS_DIR"
echo ""

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 not found. Please install Python 3.x"
    exit 1
fi
echo "✓ Python: $(python3 --version)"

# Check for SoX (play command)
if ! command -v play &> /dev/null; then
    echo ""
    echo "⚠️  SoX (play command) not found."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "   Install with: brew install sox"
        read -p "   Install now? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            brew install sox
        else
            echo "   Please install SoX manually and re-run setup."
            exit 1
        fi
    else
        echo "   Install with: sudo apt install sox (Debian/Ubuntu)"
        echo "                 sudo dnf install sox (Fedora)"
        exit 1
    fi
fi
echo "✓ SoX: $(play --version 2>&1 | head -1)"

# Create Python virtual environment
echo ""
echo "Creating Python virtual environment..."
cd "$UTTS_DIR"

if [ -d ".venv" ]; then
    echo "   .venv already exists, skipping creation"
else
    python3 -m venv .venv
    echo "✓ Created .venv"
fi

# Install piper-tts
echo ""
echo "Installing piper-tts..."
source .venv/bin/activate
pip install --upgrade pip -q
pip install piper-tts -q
echo "✓ Installed piper-tts"

# Download minimal voice set
echo ""
echo "Downloading minimal voice set (~300MB)..."
"$SCRIPT_DIR/download-voices.sh" --minimal

# Setup PATH suggestion
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║                    Setup Complete!                        ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "To add utts to your PATH, choose one:"
echo ""
echo "  Option 1: Symlink (recommended)"
echo "    ln -s $UTTS_DIR/bin/utts ~/.local/bin/utts"
echo ""
echo "  Option 2: Add to PATH in your shell config"
echo "    echo 'export PATH=\"$UTTS_DIR/bin:\$PATH\"' >> ~/.zshrc"
echo ""
echo "Test with:"
echo "  $UTTS_DIR/bin/utts \"Hello from Piper\""
echo ""
