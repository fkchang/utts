# frozen_string_literal: true

# Voice configuration management for utts
# Handles loading/saving voice mappings from YAML config

require 'yaml'
require 'fileutils'

module VoiceConfig
  CONFIG_DIR = File.expand_path('~/.config/utts')
  CONFIG_FILE = File.join(CONFIG_DIR, 'voice-mappings.yaml')

  # Default agent voice mappings (fallback if no config file)
  DEFAULT_MAPPINGS = {
    'say' => {
      'default'         => 'Samantha',
      'general-purpose' => 'Alex',
      'explore'         => 'Daniel',
      'researcher'      => 'Karen',
      'engineer'        => 'Fred',
      'architect'       => 'Reed (English (UK))',
      'designer'        => 'Moira',
      'pentester'       => 'Rishi',
      'writer'          => 'Tessa',
      'plan'            => 'Karen',
      'code-reviewer'   => 'Moira',
      'intern'          => 'Tessa'
    },
    'piper' => {
      'default'         => 'en_US-lessac-medium',
      'general-purpose' => 'en_US-ryan-medium',
      'explore'         => 'en_GB-alan-medium',
      'researcher'      => 'en_US-amy-medium',
      'engineer'        => 'en_US-joe-medium',
      'architect'       => 'en_GB-northern_english_male-medium',
      'designer'        => 'en_GB-cori-medium',
      'pentester'       => 'en_US-kusal-medium',
      'writer'          => 'en_GB-alba-medium',
      'plan'            => 'en_US-amy-medium',
      'code-reviewer'   => 'en_GB-cori-medium',
      'intern'          => 'en_US-kristin-medium'
    },
    'espeak' => {
      'default' => 'en'
    }
  }.freeze

  # Agent types in display order
  AGENT_TYPES = %w[
    default
    explore
    researcher
    engineer
    architect
    designer
    pentester
    writer
    plan
    code-reviewer
    intern
    general-purpose
  ].freeze

  # Default curated voices (fallback if config file doesn't exist)
  DEFAULT_CURATED_VOICES = [
    { id: 'en_US-lessac-medium', desc: 'Neutral US, recommended default', recommended: true },
    { id: 'en_US-ryan-medium', desc: 'US male, clear', recommended: true },
    { id: 'en_US-amy-medium', desc: 'US female, warm', recommended: true },
    { id: 'en_GB-alan-medium', desc: 'UK male, warm British', recommended: true },
    { id: 'en_GB-cori-medium', desc: 'UK female, professional', recommended: true }
  ].freeze

  # Full Piper voice catalog URL
  PIPER_VOICES_URL = 'https://huggingface.co/rhasspy/piper-voices/tree/main/en'.freeze

  class << self
    # Load voice mappings from config file or return defaults
    def load
      return deep_dup(DEFAULT_MAPPINGS) unless File.exist?(CONFIG_FILE)

      begin
        loaded = YAML.safe_load(File.read(CONFIG_FILE)) || {}
        # Merge with defaults to ensure all keys exist
        merge_with_defaults(loaded)
      rescue StandardError => e
        warn "Warning: Could not load voice config: #{e.message}"
        deep_dup(DEFAULT_MAPPINGS)
      end
    end

    # Save voice mappings to config file
    def save(mappings)
      FileUtils.mkdir_p(CONFIG_DIR)
      File.write(CONFIG_FILE, mappings.to_yaml)
      true
    rescue StandardError => e
      warn "Error saving voice config: #{e.message}"
      false
    end

    # Get voice for a specific engine and agent
    def voice_for(engine, agent, mappings = nil)
      mappings ||= load
      engine_mappings = mappings[engine] || mappings['say'] || DEFAULT_MAPPINGS['say']
      engine_mappings[agent] || engine_mappings['default']
    end

    # List available macOS say voices
    def available_say_voices
      output = `say -v ? 2>/dev/null`
      return [] if output.empty?

      output.lines.map do |line|
        # Format: "Name    locale    # Sample text"
        match = line.match(/^(\S+(?:\s+\([^)]+\))?)\s+(\S+)\s+#\s*(.*)$/)
        next unless match

        {
          name: match[1].strip,
          locale: match[2].strip,
          sample: match[3].strip
        }
      end.compact.sort_by { |v| v[:name] }
    end

    # List installed Piper voices
    def installed_piper_voices(utts_dir = nil)
      utts_dir ||= ENV.fetch('UTTS_DIR', File.expand_path('~/utts'))
      voices_dir = File.join(utts_dir, 'voices')
      return [] unless Dir.exist?(voices_dir)

      Dir.glob(File.join(voices_dir, '*.onnx')).map do |f|
        name = File.basename(f, '.onnx')
        size = File.size(f)
        { name: name, size: size, path: f }
      end.sort_by { |v| v[:name] }
    end

    # Check if a Piper voice is installed
    def piper_voice_installed?(voice_id, utts_dir = nil)
      installed_piper_voices(utts_dir).any? { |v| v[:name] == voice_id }
    end

    # Get total size of installed Piper voices
    def total_installed_size(utts_dir = nil)
      installed_piper_voices(utts_dir).sum { |v| v[:size] }
    end

    # Reset to defaults
    def reset!
      FileUtils.rm_f(CONFIG_FILE)
    end

    # Config file exists?
    def config_exists?
      File.exist?(CONFIG_FILE)
    end

    # Load curated voices from config file
    def curated_voices(utts_dir = nil)
      utts_dir ||= ENV.fetch('UTTS_DIR', File.expand_path('~/utts'))
      config_file = File.join(utts_dir, 'config', 'curated-voices.yaml')

      unless File.exist?(config_file)
        return DEFAULT_CURATED_VOICES.map { |v| v.transform_keys(&:to_s) }
      end

      begin
        loaded = YAML.safe_load(File.read(config_file), permitted_classes: [Symbol]) || []
        loaded.map do |voice|
          {
            'id' => voice['id'],
            'desc' => voice['desc'] || '',
            'recommended' => voice['recommended'] == true
          }
        end
      rescue StandardError => e
        warn "Warning: Could not load curated voices: #{e.message}"
        DEFAULT_CURATED_VOICES.map { |v| v.transform_keys(&:to_s) }
      end
    end

    # URL to full Piper voice catalog
    def piper_catalog_url
      PIPER_VOICES_URL
    end

    private

    def deep_dup(hash)
      hash.transform_values do |v|
        v.is_a?(Hash) ? v.dup : v
      end
    end

    def merge_with_defaults(loaded)
      result = deep_dup(DEFAULT_MAPPINGS)
      loaded.each do |engine, agents|
        next unless agents.is_a?(Hash)

        result[engine] ||= {}
        agents.each do |agent, voice|
          result[engine][agent] = voice
        end
      end
      result
    end
  end
end
