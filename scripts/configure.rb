#!/usr/bin/env ruby
# frozen_string_literal: true

# utts Voice Manager (Tier 3 - Premium)
# StreamWeaver-based GUI for voice configuration

require 'bundler/setup'
require 'stream_weaver'

# Load shared voice config
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'voice_config'

SCRIPT_DIR = File.dirname(File.realpath(__FILE__))
UTTS_DIR = ENV.fetch('UTTS_DIR', File.expand_path('..', SCRIPT_DIR))

def speak_test(engine, voice, message = nil)
  # Handle nil and empty string
  message = "Hello, I am #{voice}" if message.nil? || message.to_s.strip.empty?
  safe_msg = message.gsub(/[^a-zA-Z0-9\s.,!?'\-]/, '').strip[0, 100]
  # Fire and forget - don't block the HTTP response
  pid = spawn("#{UTTS_DIR}/bin/utts", safe_msg, '--engine', engine, '--voice', voice)
  Process.detach(pid)
end

def download_voice(voice_id)
  parts = voice_id.sub(/^en_/, '').split('-')
  url_path = "#{parts[0]}/#{parts[1]}/#{parts[2]}/#{voice_id}"
  voices_dir = File.join(UTTS_DIR, 'voices')

  %w[onnx onnx.json].each do |ext|
    file_path = File.join(voices_dir, "#{voice_id}.#{ext}")
    next if File.exist?(file_path)

    url = "https://huggingface.co/rhasspy/piper-voices/resolve/v1.0.0/en/#{url_path}.#{ext}"
    system('curl', '-sL', '-o', file_path, url)
  end
end

def delete_voice(voice_id)
  voices_dir = File.join(UTTS_DIR, 'voices')
  %w[onnx onnx.json].each do |ext|
    file_path = File.join(voices_dir, "#{voice_id}.#{ext}")
    FileUtils.rm_f(file_path)
  end
end

app "utts Voice Manager", layout: :wide do
  tabs :main_tabs, variant: :enclosed do
    # ===== TAB 1: Test Voices =====
    tab "Test Voices" do
      # Engine selector
      select :test_engine, %w[piper say], default: 'piper'

      text_field :test_phrase, placeholder: "Custom test phrase...", submit: false

      engine = state[:test_engine] || 'piper'
      text "Selected engine: #{engine}"

      if engine == 'piper'
        voices = VoiceConfig.installed_piper_voices(UTTS_DIR)
        us_voices = voices.select { |v| v[:name].start_with?('en_US') }
        gb_voices = voices.select { |v| v[:name].start_with?('en_GB') }

        text "Found #{voices.size} Piper voices"

        if us_voices.any?
          collapsible "US English (#{us_voices.size})", expanded: true do
            columns widths: %w[280px 100px 80px] do
              column { md "**Voice**" }
              column { md "**Size**" }
              column { text "" }
            end
            us_voices.each do |v|
              columns widths: %w[280px 100px 80px] do
                column { text v[:name] }
                column { text "#{(v[:size] / 1_000_000.0).round(1)} MB" }
                column do
                  button "Test" do |s|
                    speak_test('piper', v[:name], s[:test_phrase])
                  end
                end
              end
            end
          end
        end

        if gb_voices.any?
          collapsible "UK English (#{gb_voices.size})" do
            columns widths: %w[280px 100px 80px] do
              column { md "**Voice**" }
              column { md "**Size**" }
              column { text "" }
            end
            gb_voices.each do |v|
              columns widths: %w[280px 100px 80px] do
                column { text v[:name] }
                column { text "#{(v[:size] / 1_000_000.0).round(1)} MB" }
                column do
                  button "Test" do |s|
                    speak_test('piper', v[:name], s[:test_phrase])
                  end
                end
              end
            end
          end
        end
      else
        voices = VoiceConfig.available_say_voices.select { |v| v[:locale].start_with?('en') }
        text "Found #{voices.size} macOS voices"

        collapsible "All English Voices", expanded: true do
          columns widths: %w[200px 300px 80px] do
            column { md "**Voice**" }
            column { md "**Sample**" }
            column { text "" }
          end
          voices.first(20).each do |v|
            columns widths: %w[200px 300px 80px] do
              column { text v[:name] }
              column { text v[:sample] }
              column do
                button "Test" do |s|
                  speak_test('say', v[:name], s[:test_phrase] || v[:sample])
                end
              end
            end
          end
        end
      end
    end

    # ===== TAB 2: Agent Mappings =====
    tab "Agent Mappings" do
      text "Configure agent voice mappings"

      select :map_engine, %w[piper say], default: 'piper'

      engine = state[:map_engine] || 'piper'
      text "Mapping for: #{engine}"

      # Get available voices for this engine
      voice_list = if engine == 'piper'
                     VoiceConfig.installed_piper_voices(UTTS_DIR).map { |v| v[:name] }
                   else
                     VoiceConfig.available_say_voices.select { |v| v[:locale].start_with?('en') }.map { |v| v[:name] }
                   end

      if voice_list.empty?
        alert(variant: :warning) { text "No voices for #{engine}" }
      else
        text "#{voice_list.size} voices available"

        # Load saved config
        saved = VoiceConfig.load

        columns widths: %w[150px 300px 80px] do
          column { md "**Agent**" }
          column { md "**Voice**" }
          column { text "" }
        end

        # Simple list of agents
        agents = %w[default explore researcher engineer architect designer]

        agents.each do |agent|
          key = :"map_#{engine}_#{agent}"
          default_voice = saved.dig(engine, agent) || voice_list.first
          state[key] ||= default_voice

          columns widths: %w[150px 300px 80px] do
            column { text agent }
            column { select key, voice_list }
            column do
              button "Test" do |s|
                speak_test(engine, s[key], "Task complete")
              end
            end
          end
        end

        hstack spacing: :md do
          button "Save" do |s|
            mappings = { 'piper' => {}, 'say' => {} }
            agents.each do |agent|
              %w[piper say].each do |eng|
                k = :"map_#{eng}_#{agent}"
                mappings[eng][agent] = s[k] if s[k]
              end
            end
            VoiceConfig.save(mappings)
            s[:saved] = true
          end

          button "Reset", style: :secondary do |s|
            VoiceConfig.reset!
            agents.each do |agent|
              %w[piper say].each do |eng|
                s[:"map_#{eng}_#{agent}"] = nil
              end
            end
            s[:saved] = false
          end
        end

        if state[:saved]
          alert(variant: :success) { text "Saved!" }
        end
      end
    end

    # ===== TAB 3: Manage Voices =====
    tab "Manage Voices" do
      header3 "Piper Neural Voice Management"

      # Get installed voices with details
      installed_voices = VoiceConfig.installed_piper_voices(UTTS_DIR)
      installed_names = installed_voices.map { |v| v[:name] }
      total_size = installed_voices.sum { |v| v[:size] }  # Inline to avoid double scan
      total_mb = (total_size / 1_000_000.0).round(1)

      # ===== INSTALLED VOICES SECTION =====
      collapsible "Installed Voices (#{installed_voices.size} voices, #{total_mb} MB)", expanded: true do
        if installed_voices.empty?
          text "No Piper voices installed. Download some below!"
        else
          columns widths: %w[280px 80px 140px] do
            column { md "**Voice**" }
            column { md "**Size**" }
            column { text "" }
          end

          installed_voices.each do |v|
            columns widths: %w[280px 80px 140px] do
              column { text v[:name] }
              column { text "#{(v[:size] / 1_000_000.0).round(1)} MB" }
              column do
                hstack spacing: :sm do
                  button "Test" do
                    speak_test('piper', v[:name])
                  end
                  button "Delete", style: :danger do
                    delete_voice(v[:name])
                  end
                end
              end
            end
          end
        end
      end

      # ===== AVAILABLE TO DOWNLOAD SECTION =====
      md "---"
      header3 "Available to Download"

      # Load curated voices from config file
      voices = VoiceConfig.curated_voices(UTTS_DIR)
      # Filter out already installed voices
      available = voices.reject { |v| installed_names.include?(v['id']) }
      recommended = available.select { |v| v['recommended'] }
      additional = available.reject { |v| v['recommended'] }

      if available.empty?
        text "All curated voices are installed!"
      else
        if recommended.any?
          collapsible "Recommended (#{recommended.size})", expanded: true do
            columns widths: %w[280px 200px 100px] do
              column { md "**Voice**" }
              column { md "**Description**" }
              column { text "" }
            end

            recommended.each do |voice|
              columns widths: %w[280px 200px 100px] do
                column { text voice['id'] }
                column { text voice['desc'] }
                column do
                  button "Download" do
                    download_voice(voice['id'])
                  end
                end
              end
            end
          end
        end

        if additional.any?
          collapsible "Additional (#{additional.size})" do
            columns widths: %w[280px 200px 100px] do
              column { md "**Voice**" }
              column { md "**Description**" }
              column { text "" }
            end

            additional.each do |voice|
              columns widths: %w[280px 200px 100px] do
                column { text voice['id'] }
                column { text voice['desc'] }
                column do
                  button "Download" do
                    download_voice(voice['id'])
                  end
                end
              end
            end
          end
        end
      end

      md "---"
      md "**More voices:** [Piper Voice Catalog](#{VoiceConfig.piper_catalog_url})"
      text "Edit `config/curated-voices.yaml` to customize this list."
    end
  end

  md "_utts Voice Manager_"
end.run!
