#!/bin/bash
# Download Piper TTS voices
# Usage: download-voices.sh [--minimal|--all]
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTTS_DIR="$(dirname "$SCRIPT_DIR")"
VOICES_DIR="$UTTS_DIR/voices"
BASE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main"

mkdir -p "$VOICES_DIR"
cd "$VOICES_DIR"

download_voice() {
    local lang=$1
    local name=$2
    local quality=$3
    local filename="${lang}-${name}-${quality}"
    local url_path="en/${lang}/${name}/${quality}"

    if [ -f "${filename}.onnx" ]; then
        echo "  ✓ ${filename} (already exists)"
        return
    fi

    echo "  ↓ ${filename}..."
    curl -sL -o "${filename}.onnx" "${BASE_URL}/${url_path}/${filename}.onnx"
    curl -sL -o "${filename}.onnx.json" "${BASE_URL}/${url_path}/${filename}.onnx.json"
}

download_minimal() {
    echo "Downloading minimal voice set (~300MB)..."
    echo ""
    download_voice "en_US" "lessac" "medium"   # Default, neutral US
    download_voice "en_US" "ryan" "medium"     # US male alternative
    download_voice "en_US" "amy" "medium"      # US female
    download_voice "en_GB" "alan" "medium"     # UK male
    download_voice "en_GB" "cori" "medium"     # UK female
    echo ""
    echo "✓ Minimal set complete"
}

download_all() {
    echo "Downloading all English voices (~2.4GB)..."
    echo ""

    echo "=== en_US voices ==="
    download_voice "en_US" "amy" "low"
    download_voice "en_US" "amy" "medium"
    download_voice "en_US" "arctic" "medium"
    download_voice "en_US" "bryce" "medium"
    download_voice "en_US" "danny" "low"
    download_voice "en_US" "hfc_female" "medium"
    download_voice "en_US" "hfc_male" "medium"
    download_voice "en_US" "joe" "medium"
    download_voice "en_US" "john" "medium"
    download_voice "en_US" "kathleen" "low"
    download_voice "en_US" "kristin" "medium"
    download_voice "en_US" "kusal" "medium"
    download_voice "en_US" "l2arctic" "medium"
    download_voice "en_US" "lessac" "low"
    download_voice "en_US" "lessac" "medium"
    download_voice "en_US" "lessac" "high"
    download_voice "en_US" "libritts" "high"
    download_voice "en_US" "libritts_r" "medium"
    download_voice "en_US" "ljspeech" "medium"
    download_voice "en_US" "ljspeech" "high"
    download_voice "en_US" "norman" "medium"
    download_voice "en_US" "ryan" "low"
    download_voice "en_US" "ryan" "medium"
    download_voice "en_US" "ryan" "high"

    echo ""
    echo "=== en_GB voices ==="
    download_voice "en_GB" "alan" "low"
    download_voice "en_GB" "alan" "medium"
    download_voice "en_GB" "alba" "medium"
    download_voice "en_GB" "aru" "medium"
    download_voice "en_GB" "cori" "medium"
    download_voice "en_GB" "cori" "high"
    download_voice "en_GB" "jenny_dioco" "medium"
    download_voice "en_GB" "northern_english_male" "medium"
    download_voice "en_GB" "semaine" "medium"
    download_voice "en_GB" "southern_english_female" "low"
    download_voice "en_GB" "vctk" "medium"

    echo ""
    echo "✓ All voices complete"
}

# Parse arguments
case "${1:-}" in
    --minimal|-m)
        download_minimal
        ;;
    --all|-a)
        download_all
        ;;
    --help|-h)
        echo "Usage: download-voices.sh [--minimal|--all]"
        echo ""
        echo "Options:"
        echo "  --minimal, -m   Download 5 essential voices (~300MB)"
        echo "  --all, -a       Download all English voices (~2.4GB)"
        echo "  --help, -h      Show this help"
        echo ""
        echo "Without arguments, shows this help."
        ;;
    *)
        echo "Usage: download-voices.sh [--minimal|--all]"
        echo "Run with --help for more info"
        exit 1
        ;;
esac

echo ""
echo "Voices directory: $VOICES_DIR"
echo "Installed voices:"
ls -1 "$VOICES_DIR"/*.onnx 2>/dev/null | xargs -I{} basename {} .onnx | head -10
