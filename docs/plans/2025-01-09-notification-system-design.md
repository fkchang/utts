# Voice Notification System Design

**Date:** 2025-01-09
**Status:** Approved

## Overview

Evolve utts from a simple TTS CLI to a voice notification system with history, replay, and extensibility. Core use cases:

1. **"What did it say?"** - Missed a voice alert, need to see the text
2. **"Say that again"** - Replay audio for complex/fast notifications
3. **"I was at lunch, what happened"** - Review all notifications since being away

## Architecture

Three-layer design with optional progressive enhancement:

```
┌─────────────────────────────────────────────────────┐
│ Layer 3: Integrations (optional)                    │
│ - claude_code_history: rich metadata, tab raising   │
│ - Future integrations register on_activate hooks    │
└─────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────┐
│ Layer 2: Notification System                        │
│ - Utts::Notifications Ruby API                      │
│ - StreamWeaver dashboard UI                         │
│ - JSON storage with retention                       │
└─────────────────────────────────────────────────────┘
                         │
┌─────────────────────────────────────────────────────┐
│ Layer 1: TTS Core (existing)                        │
│ - bin/utts CLI                                      │
│ - Piper, say, espeak engines                        │
│ - Agent voice mappings                              │
└─────────────────────────────────────────────────────┘
```

**Key principle:** Layer 1 stays stdlib-only. Layers 2-3 are Tier 3 (gem dependencies).

## CLI Interface

### Existing (unchanged)

```bash
utts "Hello world"
utts "Task complete" --agent explore
utts --mute / --unmute / --status
```

### New Flags

```bash
# Caller identification
utts "Build complete" --caller "hedgeye-admin: refactor base controller"

# Metadata with action definition
utts "Ready for review" \
  --caller "pai - android research" \
  --metadata '{"iterm_tab_id":"abc123","action":{"type":"shell","command":"..."}}'

# Notification dashboard
utts --notifications    # Smart launch StreamWeaver UI

# Quick history (CLI only)
utts --history          # Show last 10 notifications
utts --history 25       # Show last 25

# Replay
utts --replay           # Re-speak most recent notification
utts --replay <id>      # Re-speak specific notification

# Silent mode (no audio, no macOS notification, just log)
utts "Background task done" --silent
```

### Mute Behavior

- **Unmuted**: Audio plays + notification logged + macOS notification
- **Muted**: No audio + notification logged + macOS notification
- **`--silent`**: No audio + notification logged + no macOS notification

## Data Model & Storage

### Files

```
~/.config/utts/
├── notifications.jsonl       # Append-only notification log
├── settings.yaml             # Retention, default behaviors
├── voice-mappings.yaml       # Existing agent voice config
└── muted                     # Existing mute flag file
```

### Notification Entry

One JSON line per notification:

```json
{
  "id": "a1b2c3d4",
  "text": "Build complete, 3 tests passing",
  "caller": "hedgeye-admin: refactor base controller",
  "agent": "engineer",
  "voice": "en_US-joe-medium",
  "timestamp": "2025-01-09T10:42:00Z",
  "metadata": {
    "iterm_tab_id": "tab-abc123",
    "action": {"type": "shell", "command": "osascript -e '...'"}
  },
  "dismissed_at": null
}
```

### Settings

```yaml
# ~/.config/utts/settings.yaml
retention_days: 5
notify_when_muted: true
```

### Cleanup

Entries older than `retention_days` pruned on each write operation.

## Action System

Actions define what happens when user clicks "Go To" in the UI.

### Built-in Action Types

```json
{"action": {"type": "shell", "command": "osascript -e '...'"}}
{"action": {"type": "url", "url": "http://localhost:3000/session/abc"}}
```

### Hook Override

Integrations can register a hook that takes precedence:

```ruby
Utts::Notifications.on_activate do |notification|
  if tab_id = notification.metadata[:iterm_tab_id]
    ClaudeCodeHistory::ITermBridge.raise_tab(tab_id)
  end
end
```

If hook is set, it handles all activations. Otherwise, fall back to `metadata[:action]`.

## Ruby API

```ruby
require 'utts/notifications'

# Log a notification
Utts::Notifications.log(
  text: "Build complete",
  caller: "hedgeye-admin: refactor",
  agent: "engineer",
  metadata: { iterm_tab_id: "x" }
)

# Query
Utts::Notifications.list                 # all undismissed
Utts::Notifications.list(limit: 10)      # last 10
Utts::Notifications.list(since: 1.hour.ago)
Utts::Notifications.find("a1b2c3d4")     # by ID

# Actions
Utts::Notifications.replay("a1b2c3d4")   # re-speak
Utts::Notifications.dismiss("a1b2c3d4")  # mark dismissed
Utts::Notifications.dismiss_all
Utts::Notifications.activate("a1b2c3d4") # trigger action

# Hook for integrations
Utts::Notifications.on_activate do |notification|
  # Custom logic
end

# Settings
Utts::Notifications.settings[:retention_days] = 7
```

## StreamWeaver Notification UI

### Launch

```bash
utts --notifications
```

### Smart Launch Behavior

1. Check for running instance (PID file at `~/.config/utts/notifications.pid`)
2. If running, open browser to existing URL
3. If not running, spawn StreamWeaver app on available port, save PID, open browser

### UI Layout

```
┌─────────────────────────────────────────────────────────┐
│ 🔊 Voice Notifications                   [Dismiss All]  │
│ 3 active · 12 in last 24h                               │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  10:42 AM  hedgeye-admin: refactor base controller      │
│  ┌───────────────────────────────────────────────────┐  │
│  │ "Build complete, 3 tests passing"                 │  │
│  └───────────────────────────────────────────────────┘  │
│                      [→ Go To]  [▶ Replay]  [Dismiss]   │
│                                                         │
│  10:38 AM  pai - researching android options            │
│  ┌───────────────────────────────────────────────────┐  │
│  │ "Found 4 promising frameworks, ready for review"  │  │
│  └───────────────────────────────────────────────────┘  │
│                      [→ Go To]  [▶ Replay]  [Dismiss]   │
│                                                         │
│  10:15 AM                                               │
│  ┌───────────────────────────────────────────────────┐  │
│  │ "Exploration complete"                            │  │
│  └───────────────────────────────────────────────────┘  │
│                                [▶ Replay]  [Dismiss]    │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ ▸ Show dismissed (9)                                    │
└─────────────────────────────────────────────────────────┘
```

### Behaviors

- Auto-refreshes when new notifications arrive (StreamWeaver reactive)
- "Go To" button only shown when action defined in metadata
- "Show dismissed" expands to see history (within retention period)
- Replay uses original agent/voice from the notification
- Toasts for action feedback ("Dismissed", "Replayed")

## macOS Notification Center Integration

Using `terminal-notifier`:

```bash
terminal-notifier \
  -title "hedgeye-admin: refactor" \
  -message "Build complete, 3 tests passing" \
  -sound default \                    # omit when muted
  -execute "utts --notifications"     # click opens dashboard
```

### Behavior

- **Unmuted**: Notification + sound + audio (TTS)
- **Muted**: Notification only (no sound, no TTS)
- **`--silent`**: Nothing visible, just logged

### Dependency

`terminal-notifier` installable via `brew install terminal-notifier`. Falls back gracefully if not installed.

## File Structure

```
utts/
├── bin/utts                      # CLI (stays stdlib-only for Tier 1-2)
├── lib/
│   ├── utts.rb                   # Gem entry point
│   ├── utts/
│   │   ├── notifications.rb      # Notifications API
│   │   ├── notification.rb       # Notification model class
│   │   ├── storage.rb            # JSONL read/write/cleanup
│   │   ├── settings.rb           # Settings management
│   │   ├── macos_notifier.rb     # terminal-notifier integration
│   │   └── voice_config.rb       # Moved from lib/
│   └── utts/
│       └── ui/
│           └── notifications.rb  # StreamWeaver components (Tier 3)
├── scripts/
│   ├── configure.rb              # Existing voice manager
│   └── notifications.rb          # Notification dashboard launcher
├── config/
│   └── curated-voices.yaml       # Existing
├── utts.gemspec                  # Gem specification
├── Gemfile
└── README.md
```

## Implementation Phases

### Phase 1: Core Notification Logging

- Add `--caller` and `--metadata` flags to `bin/utts`
- Create `Utts::Notifications` API (log, list, find)
- JSONL storage with retention cleanup
- `--history` CLI command

### Phase 2: Replay & Actions

- `--replay` CLI command
- `Utts::Notifications.replay()` and `.activate()`
- `on_activate` hook registration
- Built-in `shell` and `url` action handlers

### Phase 3: macOS Notifications

- `terminal-notifier` integration
- Mute behavior (notification without sound/audio)
- `--silent` flag for full stealth

### Phase 4: StreamWeaver Dashboard

- `scripts/notifications.rb` UI
- Smart launch (PID check, port selection)
- `utts --notifications` command
- Reactive updates

### Phase 5: Gem Packaging

- `utts.gemspec`
- Reorganize lib structure
- Documentation updates
- Publish to RubyGems

## Integration Example: claude_code_history

```ruby
# In claude_code_history initializer
require 'utts/notifications'

Utts::Notifications.on_activate do |n|
  if tab_id = n.metadata[:iterm_tab_id]
    ClaudeCodeHistory::ITermBridge.raise_tab(tab_id)
  elsif url = n.metadata[:dashboard_url]
    `open "#{url}"`
  end
end

# When a Claude Code session completes a task
Utts::Notifications.log(
  text: "Build complete, all tests passing",
  caller: "#{project.name}: #{session.intent}",
  agent: session.agent_type,
  metadata: {
    iterm_tab_id: session.iterm_tab_id,
    session_id: session.id,
    project_id: project.id
  }
)
```
