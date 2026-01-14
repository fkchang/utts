# utts - For LLMs

Quick reference for AI assistants working with utts.

## What It Is

utts (Unified Text-to-Speech) is a Ruby CLI that provides text-to-speech across multiple engines with agent-specific voice mapping. Primary use case: voice notifications for Claude Code sessions.

## Quick Usage

```bash
# Basic
utts "message"

# With agent voice
utts "Task complete" --agent explore

# Prosody control
utts "Fast speech" --rate 250        # Words per minute
utts "High pitch" --pitch 60         # 0-99 (45=normal)

# Emotion-based prosody (auto-detected or explicit)
utts "Finally fixed the bug!"        # Auto-detects :celebration → faster, higher pitch
utts "Critical error!"               # Auto-detects :urgent → very fast, high pitch
utts "Hello" --emotion excited       # Explicit emotion override
utts --list-emotions                 # Show available emotions

# Mute/unmute (runtime, no restart)
utts --mute
utts --unmute

# Notification history
utts --history
utts --replay
```

## Emotion Detection

Auto-detects emotion from message and applies prosody:

| Emotion | Triggers | Effect |
|---------|----------|--------|
| excited | breakthrough, amazing, wow, !! | Fast, high pitch |
| celebration | finally, fixed, tests pass, 🎉 | Moderately fast |
| success | completed, done, ready, ✅ | Normal, warm |
| caution | warning, partial, issue, ⚠️ | Slow, low pitch |
| urgent | critical, error, broken, ❌ | Very fast, high |
| question | needs input, waiting, ?? | Slightly slow |
| neutral | (default) | Normal pace |

## Agent Voice Mapping

Built-in mappings for AI agent types:

| Agent Type | say Voice | Piper Voice |
|------------|-----------|-------------|
| default | Samantha | en_US-lessac-medium |
| explore | Daniel | en_GB-alan-medium |
| researcher | Karen | en_US-amy-medium |
| engineer | Fred | en_US-joe-medium |
| architect | Reed | en_GB-northern_english_male-medium |
| designer | Moira | en_GB-cori-medium |
| pentester | Rishi | en_US-kusal-medium |

Custom mappings: `~/.config/utts/voice-mappings.yaml`

## Claude Code Integration

utts is designed to work with Claude Code hooks. See:
- `~/work/claude_code_history/docs/voice-notification-architecture.md` - Full integration docs
- `~/work/claude_code_history/bin/session-event` - Hook handler that calls utts
- `~/work/pai/.claude/.claude/hooks/local/stop-hook.rb` - Direct Ruby hook example

## Key Files

| File | Purpose |
|------|---------|
| `bin/utts` | Main CLI (Ruby, stdlib only) |
| `lib/utts/` | Engine implementations |
| `scripts/configure.rb` | StreamWeaver voice manager UI |
| `voices/` → piper-tts/voices | Symlink to Piper voice models |

## Engine Priority

Auto-detection order:
1. **Piper** - If installed (best quality)
2. **say** - macOS built-in (no setup)
3. **espeak** - Linux fallback

## Configuration Files

```
~/.config/utts/
├── muted                    # Control file (presence = muted)
├── voice-mappings.yaml      # Agent → voice mappings
└── project-voices.yaml      # Project → agent mappings
```

## Why utts vs ElevenLabs

| Aspect | utts | ElevenLabs |
|--------|------|------------|
| Cost | Free | ~$5-22/mo |
| Latency | ~50ms | ~500ms+ |
| Offline | Yes | No |
| Server | No | Required |

See `~/work/claude_code_history/docs/voice-notification-architecture.md` for detailed comparison.
