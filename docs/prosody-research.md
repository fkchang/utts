# Adding Prosody to utts - Research

How to add emotional/expressive speech control to utts.

## What is Prosody?

Prosody refers to the rhythm, stress, and intonation of speech. In TTS, prosody control means adjusting:
- **Rate** - Speaking speed (words per minute)
- **Pitch** - Voice frequency (higher/lower)
- **Volume** - Loudness
- **Emphasis** - Stress on specific words
- **Pauses** - Silence between phrases

## Current utts Architecture

```ruby
def speak_say(message, voice, rate)
  system('/usr/bin/say', '-v', voice, '-r', rate, message)
end

def speak_piper(message, voice)
  # Fixed parameters, no prosody control
  cmd = "echo '#{message}' | piper --model '#{voice}' --output-raw | play ..."
end

def speak_espeak(message, voice)
  system(espeak_cmd, '-v', voice, message)
end
```

**Current state:** Only macOS `say` has rate control (`-r`). No pitch, volume, or emotion support.

---

## Engine Prosody Capabilities

### macOS `say` - Full Prosody Support

The `say` command supports inline embedded commands:

```bash
# Rate control
say -r 200 "Normal speed"
say "[[rate 300]] Fast speech [[rate 150]] slow speech"

# Pitch control
say "[[pbas 50]] High pitch [[pbas 30]] Low pitch"

# Pitch modulation
say "[[pmod 100]] Excited! [[pmod 30]] Monotone."

# Volume
say "[[volm 0.5]] Quiet [[volm 1.0]] Normal"

# Emphasis
say "[[emph +]] Important [[emph -]] less important"

# Pauses
say "Hello [[slnc 500]] world"  # 500ms pause

# Combined
say "[[rate 220; pmod 90; pbas 45; volm 0.8]] Excited speech!"
```

**Full support for:** rate, pitch (pbas), pitch modulation (pmod), volume (volm), emphasis, pauses (slnc)

**Limitation:** Some newer voices don't honor all embedded commands.

Sources: [Apple Developer Docs](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/SpeakText.html), [SS64 say man page](https://ss64.com/mac/say.html), [Matt Montag's speech synthesis markup](https://www.mattmontag.com/personal/mac-os-x-speech-synthesis-markup)

---

### Piper TTS - Runtime Parameters

Piper supports prosody via command-line arguments:

```bash
# Speed control (length_scale: 1.0 = normal, <1 = faster, >1 = slower)
echo "Fast speech" | piper --model voice.onnx --length-scale 0.8 --output-raw

# Voice variation (noise_scale)
echo "More expressive" | piper --model voice.onnx --noise-scale 0.8 --output-raw

# Phoneme duration variation (noise_w)
echo "Natural rhythm" | piper --model voice.onnx --noise-w 0.9 --output-raw

# Sentence silence
echo "Pause between sentences." | piper --model voice.onnx --sentence-silence 0.5 --output-raw
```

| Parameter | Default | Effect |
|-----------|---------|--------|
| `--length-scale` | 1.0 | Speed: smaller = faster |
| `--noise-scale` | 0.667 | Voice variation/expressiveness |
| `--noise-w` | 0.8 | Phoneme duration variation |
| `--sentence-silence` | 0.2 | Pause between sentences (seconds) |

**Note:** Piper does NOT support inline SSML tags. Parameters are per-utterance only.

Sources: [Piper GitHub](https://github.com/rhasspy/piper), [DeepWiki Piper](https://deepwiki.com/rhasspy/piper/2-core-tts-engine), [Home Assistant Community](https://community.home-assistant.io/t/how-to-set-piper-speaking-rate/662014)

---

### espeak-ng - SSML Support

espeak-ng supports SSML prosody tags:

```bash
# Rate
espeak-ng '<prosody rate="fast">Quick speech</prosody>'
espeak-ng '<prosody rate="150%">150 percent speed</prosody>'

# Pitch
espeak-ng '<prosody pitch="75">Higher pitch</prosody>'

# Volume
espeak-ng '<prosody volume="loud">Loud speech</prosody>'
espeak-ng '<prosody volume="+6dB">Louder</prosody>'

# Combined
espeak-ng '<prosody rate="fast" pitch="high" volume="loud">Excited!</prosody>'
```

**Command-line defaults:**
- Volume: 0-200 (default 100)
- Pitch: 0-99 (default 50)
- Speed: words-per-minute (default 175)

```bash
espeak-ng -a 150 -p 70 -s 200 "Loud, high, fast"
```

Sources: [espeak-ng docs](https://github.com/espeak-ng/espeak-ng/blob/master/docs/markup.md), [eSpeak SSML](https://espeak.sourceforge.net/ssml.html)

---

## Proposed Implementation

### 1. Emotion Detection (from pai-voice-system)

Port the prosody-enhancer pattern detection:

```ruby
EMOTION_PATTERNS = {
  excited: [
    /\b(breakthrough|discovered|found it|eureka|amazing)\b/i,
    /!{2,}|💥|🔥|⚡/
  ],
  celebration: [
    /\b(finally|at last|we did it|victory)\b/i,
    /\b(all .* passing|zero errors)\b/i,
    /🎉|🥳/
  ],
  success: [
    /\b(completed|finished|done|fixed|resolved)\b/i,
    /✅|✨/
  ],
  caution: [
    /\b(warning|careful|partial|incomplete)\b/i,
    /⚠️/
  ],
  urgent: [
    /\b(urgent|critical|failing|broken|alert)\b/i,
    /🚨|❌/
  ]
}

def detect_emotion(message)
  EMOTION_PATTERNS.each do |emotion, patterns|
    patterns.each { |p| return emotion if p.match?(message) }
  end
  :neutral
end
```

### 2. Emotion-to-Prosody Mapping

Define prosody parameters per emotion:

```ruby
PROSODY_SETTINGS = {
  # emotion => { say: {}, piper: {}, espeak: {} }
  excited: {
    say: { rate: 240, pmod: 100, pbas: 50 },
    piper: { length_scale: 0.85, noise_scale: 0.8 },
    espeak: { rate: 'fast', pitch: 60, volume: 'loud' }
  },
  celebration: {
    say: { rate: 220, pmod: 90, pbas: 48 },
    piper: { length_scale: 0.9, noise_scale: 0.75 },
    espeak: { rate: '120%', pitch: 55 }
  },
  success: {
    say: { rate: 200, pmod: 70, pbas: 45 },
    piper: { length_scale: 1.0, noise_scale: 0.7 },
    espeak: { rate: 'medium', pitch: 50 }
  },
  caution: {
    say: { rate: 170, pmod: 40, pbas: 38 },
    piper: { length_scale: 1.15, noise_scale: 0.5 },
    espeak: { rate: 'slow', pitch: 40 }
  },
  urgent: {
    say: { rate: 260, pmod: 110, pbas: 55 },
    piper: { length_scale: 0.75, noise_scale: 0.9 },
    espeak: { rate: 'x-fast', pitch: 70, volume: 'x-loud' }
  },
  neutral: {
    say: { rate: 200, pmod: 60, pbas: 42 },
    piper: { length_scale: 1.0, noise_scale: 0.667 },
    espeak: { rate: 'medium', pitch: 50 }
  }
}
```

### 3. Updated Engine Functions

```ruby
def speak_say(message, voice, emotion = :neutral)
  settings = PROSODY_SETTINGS.dig(emotion, :say) || PROSODY_SETTINGS[:neutral][:say]

  # Build embedded commands
  prosody = "[[rate #{settings[:rate]}; pmod #{settings[:pmod]}; pbas #{settings[:pbas]}]]"

  system('/usr/bin/say', '-v', voice, "#{prosody} #{message}")
end

def speak_piper(message, voice, emotion = :neutral)
  settings = PROSODY_SETTINGS.dig(emotion, :piper) || PROSODY_SETTINGS[:neutral][:piper]

  piper_bin = File.join(UTTS_DIR, '.venv', 'bin', 'piper')
  voice_path = File.join(UTTS_DIR, 'voices', "#{voice}.onnx")

  cmd = "echo '#{escape(message)}' | " \
        "'#{piper_bin}' " \
        "--model '#{voice_path}' " \
        "--length-scale #{settings[:length_scale]} " \
        "--noise-scale #{settings[:noise_scale]} " \
        "--output-raw 2>/dev/null | " \
        "play -q -r 22050 -b 16 -e signed -c 1 -t raw -"

  system(cmd)
end

def speak_espeak(message, voice, emotion = :neutral)
  settings = PROSODY_SETTINGS.dig(emotion, :espeak) || PROSODY_SETTINGS[:neutral][:espeak]

  # Build SSML
  ssml = "<prosody"
  ssml += " rate=\"#{settings[:rate]}\"" if settings[:rate]
  ssml += " pitch=\"#{settings[:pitch]}\"" if settings[:pitch]
  ssml += " volume=\"#{settings[:volume]}\"" if settings[:volume]
  ssml += ">#{message}</prosody>"

  espeak_cmd = system('which espeak-ng > /dev/null 2>&1') ? 'espeak-ng' : 'espeak'
  system(espeak_cmd, '-v', voice, '-m', ssml)  # -m enables SSML
end
```

### 4. CLI Interface

```bash
# Auto-detect emotion from message
utts "Finally fixed the bug!"  # Detects :celebration

# Explicit emotion
utts "System ready" --emotion success
utts "Warning: partial results" --emotion caution

# Manual prosody override
utts "Custom speech" --rate 250 --pitch 60

# List emotions
utts --list-emotions
```

### 5. Configuration File

Allow user customization of prosody settings:

```yaml
# ~/.config/utts/prosody.yaml
emotions:
  excited:
    say: { rate: 250, pmod: 110 }
    piper: { length_scale: 0.8 }
  custom_emotion:
    say: { rate: 180, pmod: 50, pbas: 35 }
    piper: { length_scale: 1.2 }
```

---

## Implementation Phases

### Phase 1: Basic Prosody ✅ IMPLEMENTED

Added `--rate` and `--pitch` flags that work across engines:

```bash
utts "Hello" --rate 250            # Speaking rate (wpm)
utts "Hello" --pitch 60            # Pitch 0-99 (45=normal)
```

**Engine mappings:**
- **say**: rate → `-r` flag, pitch → `[[pbas N; pmod N]]` embedded commands
- **piper**: rate → `--length-scale`, pitch → `--noise-scale`
- **espeak**: rate → `-s` flag, pitch → `-p` flag

### Phase 2: Emotion Detection ✅ IMPLEMENTED

Auto-detects emotion from message content and applies appropriate prosody:

```bash
utts "Finally fixed the bug!"      # Detects :celebration → rate 220, pitch 48
utts "Critical error!"             # Detects :urgent → rate 260, pitch 55
utts "Hello world"                 # Detects :neutral → rate 200, pitch 42

utts "Hello" --emotion excited     # Explicit emotion override
utts --list-emotions               # Show available emotions
```

**Available emotions:** excited, celebration, success, caution, urgent, question, neutral

**Detection patterns:** Keywords (finally, fixed, error, warning) and emojis (🎉, ❌, ⚠️)

### Phase 3: Full Prosody (Not Started)

- SSML support for espeak-ng
- Embedded commands for say (advanced: volume, emphasis, pauses)
- Configuration file for custom emotions (`~/.config/utts/prosody.yaml`)
- StreamWeaver UI for prosody testing

---

## Testing Matrix

| Engine | Rate | Pitch | Volume | Emphasis | Pauses | SSML |
|--------|------|-------|--------|----------|--------|------|
| say | ✅ -r flag + [[rate]] | ✅ [[pbas]] | ✅ [[volm]] | ✅ [[emph]] | ✅ [[slnc]] | ❌ |
| piper | ✅ --length-scale | ⚠️ via noise_scale | ❌ | ❌ | ✅ --sentence-silence | ❌ |
| espeak | ✅ -s flag + SSML | ✅ -p flag + SSML | ✅ -a flag + SSML | ❌ | ❌ | ✅ |

---

## References

- [Piper TTS GitHub](https://github.com/rhasspy/piper)
- [Apple say command docs](https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/SpeakText.html)
- [espeak-ng SSML markup](https://github.com/espeak-ng/espeak-ng/blob/master/docs/markup.md)
- [pai-voice-system prosody-enhancer.ts](~/pai2/.claude/Packs/pai-voice-system/src/hooks/lib/prosody-enhancer.ts)
- [py3-tts-wrapper](https://pypi.org/project/py3-tts-wrapper/) - Unified TTS with SSML support
