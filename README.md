# utts - Unified Text-to-Speech

A Ruby CLI for text-to-speech supporting multiple engines: Piper neural TTS, macOS `say`, and Linux `espeak-ng`.

**⚠️ Developed on macOS, Linux untested** - PRs welcome for fixes.

## Quick Start

```bash
# Clone
git clone https://github.com/fkchang/utts ~/utts

# Use immediately (macOS uses built-in 'say')
~/utts/bin/utts "Hello world"

# Optional: Add to PATH
ln -s ~/utts/bin/utts ~/.local/bin/utts
```

## Installation Tiers

| Tier | What You Get | Requirements |
|------|-------------|--------------|
| **Tier 1: Minimal** | CLI with `say`/`espeak` | Git clone only |
| **Tier 2: Standard** | + Piper neural voices | Python 3, SoX |
| **Tier 3: Premium** | + Interactive setup wizard | Ruby gems |

### Tier 1: Minimal (Clone Only)

Works immediately on macOS (uses built-in `say`):

```bash
git clone https://github.com/fkchang/utts ~/utts
~/utts/bin/utts "Hello from say"
```

On Linux, install `espeak-ng` first:
```bash
sudo apt install espeak-ng  # Debian/Ubuntu
sudo dnf install espeak-ng  # Fedora
```

**No gem install needed** - CLI uses only Ruby stdlib.

### Tier 2: Standard (+ Piper Neural TTS)

High-quality neural voices:

```bash
cd ~/utts
./scripts/setup.sh
```

This installs:
- Python virtual environment
- piper-tts package
- SoX (for audio playback)
- 5 minimal voices (~300MB)

Test:
```bash
utts "Hello from Piper neural TTS"
```

### Tier 3: Premium (+ StreamWeaver Wizard)

Interactive browser-based setup:

```bash
cd ~/utts
bundle install
ruby scripts/setup.rb
```

Requires modern Ruby (3.0+) and bundler.

## Usage

```bash
# Basic
utts "Hello world"

# Specific engine
utts "Hello" --engine piper
utts "Hello" --engine say
utts "Hello" --engine espeak

# Specific voice
utts "British accent" --voice Daniel
utts "Neural voice" --engine piper --voice en_GB-alan-medium

# Agent mode (for AI assistants)
utts "Task complete" --agent explore

# Mute/unmute (no restart needed!)
utts --mute      # Silence TTS
utts --unmute    # Restore TTS
utts --status    # Check status

# List options
utts --list-voices
utts --list-agents
utts --help
```

## Engine Auto-Detection

`utts` automatically selects the best available engine:

1. **Piper** - If installed (high quality neural voices)
2. **say** - macOS built-in (no install needed)
3. **espeak** - Linux fallback

## Agent Voice Mappings

For AI assistant integration, `utts` maps agent types to distinct voices:

| Agent | say (macOS) | Piper |
|-------|-------------|-------|
| default | Samantha | en_US-lessac-medium |
| explore | Daniel | en_GB-alan-medium |
| researcher | Karen | en_US-amy-medium |
| engineer | Fred | en_US-joe-medium |
| ... | ... | ... |

Use with `--agent TYPE`:
```bash
utts "Exploration complete" --agent explore
```

## Runtime Mute

Silence TTS without restarting your terminal:

```bash
utts --mute     # Creates ~/.config/utts/muted
utts --unmute   # Removes the file
```

Perfect for meetings - mute, do your thing, unmute.

## Voice Download

```bash
# Minimal set (5 voices, ~300MB)
./scripts/download-voices.sh --minimal

# All English voices (~2.4GB)
./scripts/download-voices.sh --all

# List installed
./scripts/list-voices.sh
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `UTTS_DIR` | Installation directory | Auto-detected |
| `TTS_VOICE` | Default voice | Engine-specific |
| `TTS_RATE` | Speaking rate (say only) | 200 |

## File Structure

```
utts/
├── bin/utts              # Main CLI (stdlib only)
├── scripts/
│   ├── setup.sh          # Tier 2 installer
│   ├── setup.rb          # Tier 3 wizard
│   ├── download-voices.sh
│   └── list-voices.sh
├── voices/               # Piper voice models
├── .venv/                # Python venv (after setup)
├── Gemfile               # Ruby deps (Tier 3)
├── requirements.txt      # Python deps
└── LICENSE               # MIT
```

## Credits

- [Piper TTS](https://github.com/rhasspy/piper) - Neural TTS engine
- [StreamWeaver](https://github.com/fkchang/stream_weaver) - Ruby reactive UI

## License

MIT
