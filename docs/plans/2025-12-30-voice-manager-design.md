# Voice Manager UI Design

**Date:** 2025-12-30
**Status:** Approved

## Overview

StreamWeaver-based voice manager for utts with three tabs:
1. Test Voices - audition available voices
2. Agent Mappings - configure which voice each agent type uses
3. Download Voices - manage Piper voice downloads

## Architecture

### Files

```
utts/
├── scripts/
│   └── configure.rb        # StreamWeaver voice manager
├── lib/
│   └── voice_config.rb     # Shared config loading logic
└── bin/utts                 # Update to read from YAML config
```

### Config Location

```
~/.config/utts/
├── muted                    # Existing mute control file
└── voice-mappings.yaml      # Agent voice mappings
```

### YAML Format

```yaml
say:
  default: Samantha
  explore: Daniel
  researcher: Karen
  engineer: Fred
  architect: "Reed (English (UK))"
  designer: Moira
  pentester: Rishi
  writer: Tessa
  plan: Karen
  code-reviewer: Moira
  intern: Tessa

piper:
  default: en_US-lessac-medium
  explore: en_GB-alan-medium
  researcher: en_US-amy-medium
  engineer: en_US-joe-medium
  architect: en_GB-northern_english_male-medium
  designer: en_GB-cori-medium
  pentester: en_US-kusal-medium
  writer: en_GB-alba-medium
  plan: en_US-amy-medium
  code-reviewer: en_GB-cori-medium
  intern: en_US-kristin-medium
```

### Behavior

- `bin/utts` loads YAML config if exists, falls back to hardcoded defaults
- `configure.rb` reads/writes this YAML file
- Shared `lib/voice_config.rb` handles loading logic

### Dependencies

- `configure.rb` requires StreamWeaver (Tier 3)
- `bin/utts` stays stdlib-only (YAML is in stdlib)

---

## Tab 1: Test Voices

### Layout

- Engine toggle: macOS say / Piper (radio buttons)
- Custom test phrase input with global "Speak" button
- Voice table with columns: Voice, Sample Text, Test button
- Shows voice count at bottom

### Behavior

- Engine toggle switches between say/piper voice lists
- Custom test phrase overrides sample text
- Per-voice Test button speaks using that voice
- For Piper: only shows installed voices

---

## Tab 2: Agent Mappings

### Layout

- Engine toggle: macOS say / Piper
- Agent mapping table with columns: Agent, Voice dropdown, Test button
- Reset to Defaults button
- Save Changes button with success indicator

### Agents

- default, explore, researcher, engineer, architect
- designer, pentester, writer, plan, code-reviewer, intern

### Behavior

- Engine toggle switches which voices populate dropdowns
- Test button speaks "Task complete" in mapped voice
- Save writes to `~/.config/utts/voice-mappings.yaml`
- Reset restores hardcoded defaults from bin/utts

---

## Tab 3: Download Voices

### Layout

- Header showing installed count and total size
- Curated voice table (~20 voices) with columns:
  - Voice name (★ for recommended)
  - Description
  - Size
  - Status (Installed checkmark or Download button)
- Delete Unused Voices button

### Curated Voice List

Essential (used in default mappings):
- en_US-lessac-medium (default)
- en_US-ryan-medium
- en_US-amy-medium
- en_US-joe-medium
- en_US-kristin-medium
- en_US-kusal-medium
- en_GB-alan-medium
- en_GB-cori-medium
- en_GB-alba-medium
- en_GB-northern_english_male-medium

Additional options:
- en_US-libritts-high
- en_US-ljspeech-medium
- en_GB-jenny_dioco-medium
- en_GB-semaine-medium
- en_GB-southern_english_female-low
- (5-10 more quality voices)

### Behavior

- Download button shows progress, converts to checkmark on complete
- Delete Unused removes voices not referenced in any agent mapping
- Star indicates voice is used in default agent mappings
