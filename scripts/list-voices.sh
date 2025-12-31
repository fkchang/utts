#!/bin/bash
# List available Piper TTS voices
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UTTS_DIR="$(dirname "$SCRIPT_DIR")"
VOICES_DIR="$UTTS_DIR/voices"

echo "Piper TTS Voices"
echo "================"
echo "Directory: $VOICES_DIR"
echo ""

if [ ! -d "$VOICES_DIR" ] || [ -z "$(ls -A "$VOICES_DIR"/*.onnx 2>/dev/null)" ]; then
    echo "(no voices installed)"
    echo ""
    echo "Run: $SCRIPT_DIR/download-voices.sh --minimal"
    exit 0
fi

echo "Installed:"
for f in "$VOICES_DIR"/*.onnx; do
    voice=$(basename "$f" .onnx)
    size=$(du -h "$f" | cut -f1)
    echo "  $voice ($size)"
done
