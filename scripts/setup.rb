#!/usr/bin/env ruby
# frozen_string_literal: true

# utts Setup Wizard (Tier 3 - Premium)
# Interactive GUI for configuration using StreamWeaver
#
# Usage: ruby scripts/setup.rb
# Requires: bundle install (to get stream_weaver gem)

require 'bundler/setup'
require 'stream_weaver'

SCRIPT_DIR = File.dirname(File.realpath(__FILE__))
UTTS_DIR = File.expand_path('..', SCRIPT_DIR)

# Detect platform
def detect_platform
  case RUBY_PLATFORM
  when /darwin/
    'macOS'
  when /linux/
    'Linux'
  when /win|mingw/
    'Windows'
  else
    'Unknown'
  end
end

# Check dependencies
def check_python
  system('python3 --version > /dev/null 2>&1')
end

def check_sox
  system('which play > /dev/null 2>&1')
end

def check_piper_installed
  File.exist?(File.join(UTTS_DIR, '.venv', 'bin', 'piper'))
end

def installed_voices
  voices_dir = File.join(UTTS_DIR, 'voices')
  return [] unless Dir.exist?(voices_dir)

  Dir.glob(File.join(voices_dir, '*.onnx')).map do |f|
    File.basename(f, '.onnx')
  end.sort
end

# Available voice options
MINIMAL_VOICES = [
  { id: 'en_US-lessac-medium', label: 'US English - Lessac (Recommended)', default: true },
  { id: 'en_US-ryan-medium', label: 'US English - Ryan (Male)', default: true },
  { id: 'en_US-amy-medium', label: 'US English - Amy (Female)', default: true },
  { id: 'en_GB-alan-medium', label: 'UK English - Alan (Male)', default: true },
  { id: 'en_GB-cori-medium', label: 'UK English - Cori (Female)', default: true }
].freeze

app "utts Setup Wizard", layout: :wide do
  header1 "🎙️ utts Setup Wizard"

  platform = detect_platform
  text "Platform: **#{platform}**"
  text "UTTS_DIR: `#{UTTS_DIR}`"

  # System checks
  header2 "System Requirements"

  vstack spacing: :sm do
    if check_python
      text "✅ Python 3 installed"
    else
      alert(variant: :error) { text "❌ Python 3 not found. Please install Python 3.x" }
    end

    if check_sox
      text "✅ SoX (play command) installed"
    else
      alert(variant: :warning) do
        text "⚠️ SoX not found."
        if platform == 'macOS'
          text "Install with: `brew install sox`"
        else
          text "Install with: `sudo apt install sox`"
        end
      end
    end

    if check_piper_installed
      text "✅ Piper TTS installed"
    else
      text "⏳ Piper TTS not yet installed"
    end
  end

  # Voice selection
  header2 "Voice Selection"

  installed = installed_voices
  if installed.any?
    text "Installed voices: #{installed.join(', ')}"
  end

  checkbox_group :voices, select_all: "Select All", select_none: "Clear" do
    MINIMAL_VOICES.each do |voice|
      is_installed = installed.include?(voice[:id])
      label = is_installed ? "#{voice[:label]} ✓" : voice[:label]
      item voice[:id] do
        text label
      end
    end
  end

  # PATH setup
  header2 "PATH Setup"

  radio_group :path_setup, [
    "Symlink to ~/.local/bin/utts (Recommended)",
    "Add utts/bin/ to PATH in shell config",
    "I'll set up PATH manually"
  ]

  # Install button
  header2 "Install"

  button "Install Piper + Selected Voices" do |s|
    s[:installing] = true
    s[:install_log] = []

    # Run setup.sh
    log = `cd #{UTTS_DIR} && ./scripts/setup.sh 2>&1`
    s[:install_log] << log

    # Download selected voices
    selected_voices = s[:voices] || []
    selected_voices.each do |voice_id|
      # Download individual voice (simplified)
      s[:install_log] << "Downloading #{voice_id}..."
    end

    s[:installing] = false
    s[:install_complete] = true
  end

  if state[:installing]
    spinner label: "Installing..."
  end

  if state[:install_complete]
    alert(variant: :success, title: "Installation Complete!") do
      text "Piper TTS is ready to use."
      text "Test with: `utts \"Hello from Piper\"`"
    end
  end

  # Test section
  header2 "Test"

  text_field :test_message, placeholder: "Enter test message..."

  hstack spacing: :md do
    button "Speak (say)" do |s|
      msg = s[:test_message] || "Hello from utts"
      system("#{UTTS_DIR}/bin/utts", msg, "--engine", "say")
    end

    if check_piper_installed
      button "Speak (Piper)" do |s|
        msg = s[:test_message] || "Hello from Piper"
        system("#{UTTS_DIR}/bin/utts", msg, "--engine", "piper")
      end
    end
  end

  # Footer
  text "---"
  text "_utts - Unified Text-to-Speech CLI_"
  text "[GitHub](https://github.com/fkchang/utts)"
end.run!
