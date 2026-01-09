# Phase 1: Core Notification Logging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `--caller`, `--metadata` flags to utts CLI, implement JSONL notification storage with retention, and add `--history` command.

**Architecture:** Notifications stored in `~/.config/utts/notifications.jsonl` as append-only log. New `Utts::Notifications` module handles storage/retrieval. CLI flags pass caller/metadata through to logging. Cleanup runs on each write.

**Tech Stack:** Ruby stdlib (JSON, FileUtils), no new gem dependencies for core functionality.

---

## Task 1: Create Notification Model Class

**Files:**
- Create: `lib/utts/notification.rb`

**Step 1: Create directory structure**

```bash
mkdir -p lib/utts
```

**Step 2: Write the Notification class**

```ruby
# lib/utts/notification.rb
# frozen_string_literal: true

require 'json'
require 'securerandom'
require 'time'

module Utts
  class Notification
    attr_reader :id, :text, :caller, :agent, :voice, :timestamp, :metadata, :dismissed_at

    def initialize(
      text:,
      caller: nil,
      agent: nil,
      voice: nil,
      metadata: {},
      id: nil,
      timestamp: nil,
      dismissed_at: nil
    )
      @id = id || SecureRandom.hex(4)
      @text = text
      @caller = caller
      @agent = agent
      @voice = voice
      @timestamp = timestamp || Time.now.utc.iso8601
      @metadata = metadata || {}
      @dismissed_at = dismissed_at
    end

    def dismissed?
      !@dismissed_at.nil?
    end

    def dismiss!
      @dismissed_at = Time.now.utc.iso8601
    end

    def to_h
      {
        id: @id,
        text: @text,
        caller: @caller,
        agent: @agent,
        voice: @voice,
        timestamp: @timestamp,
        metadata: @metadata,
        dismissed_at: @dismissed_at
      }
    end

    def to_json(*args)
      to_h.to_json(*args)
    end

    def self.from_hash(hash)
      new(
        id: hash['id'] || hash[:id],
        text: hash['text'] || hash[:text],
        caller: hash['caller'] || hash[:caller],
        agent: hash['agent'] || hash[:agent],
        voice: hash['voice'] || hash[:voice],
        timestamp: hash['timestamp'] || hash[:timestamp],
        metadata: hash['metadata'] || hash[:metadata] || {},
        dismissed_at: hash['dismissed_at'] || hash[:dismissed_at]
      )
    end

    def self.from_json(json_string)
      from_hash(JSON.parse(json_string))
    end
  end
end
```

**Step 3: Commit**

```bash
git add lib/utts/notification.rb
git commit -m "feat: add Notification model class"
```

---

## Task 2: Create Storage Module

**Files:**
- Create: `lib/utts/storage.rb`

**Step 1: Write the Storage module**

```ruby
# lib/utts/storage.rb
# frozen_string_literal: true

require 'json'
require 'fileutils'
require_relative 'notification'

module Utts
  module Storage
    CONFIG_DIR = File.expand_path('~/.config/utts')
    NOTIFICATIONS_FILE = File.join(CONFIG_DIR, 'notifications.jsonl')
    SETTINGS_FILE = File.join(CONFIG_DIR, 'settings.yaml')

    DEFAULT_RETENTION_DAYS = 5

    class << self
      def ensure_config_dir
        FileUtils.mkdir_p(CONFIG_DIR)
      end

      def retention_days
        return DEFAULT_RETENTION_DAYS unless File.exist?(SETTINGS_FILE)

        begin
          settings = YAML.safe_load(File.read(SETTINGS_FILE)) || {}
          settings['retention_days'] || DEFAULT_RETENTION_DAYS
        rescue StandardError
          DEFAULT_RETENTION_DAYS
        end
      end

      def append(notification)
        ensure_config_dir
        File.open(NOTIFICATIONS_FILE, 'a') do |f|
          f.puts(notification.to_json)
        end
        cleanup_old_entries
        notification
      end

      def all
        return [] unless File.exist?(NOTIFICATIONS_FILE)

        File.readlines(NOTIFICATIONS_FILE).filter_map do |line|
          next if line.strip.empty?

          Notification.from_json(line)
        rescue JSON::ParserError
          nil
        end
      end

      def undismissed
        all.reject(&:dismissed?)
      end

      def find(id)
        all.find { |n| n.id == id }
      end

      def list(limit: nil, since: nil, include_dismissed: false)
        results = include_dismissed ? all : undismissed
        results = results.select { |n| Time.parse(n.timestamp) >= since } if since
        results = results.sort_by { |n| Time.parse(n.timestamp) }.reverse
        results = results.take(limit) if limit
        results
      end

      def update(notification)
        notifications = all
        index = notifications.find_index { |n| n.id == notification.id }
        return nil unless index

        notifications[index] = notification
        rewrite_all(notifications)
        notification
      end

      def dismiss(id)
        notification = find(id)
        return nil unless notification

        notification.dismiss!
        update(notification)
      end

      def dismiss_all
        notifications = all
        notifications.each(&:dismiss!)
        rewrite_all(notifications)
      end

      def cleanup_old_entries
        cutoff = Time.now - (retention_days * 24 * 60 * 60)
        notifications = all.select { |n| Time.parse(n.timestamp) >= cutoff }
        rewrite_all(notifications)
      end

      private

      def rewrite_all(notifications)
        ensure_config_dir
        File.open(NOTIFICATIONS_FILE, 'w') do |f|
          notifications.each { |n| f.puts(n.to_json) }
        end
      end
    end
  end
end
```

**Step 2: Commit**

```bash
git add lib/utts/storage.rb
git commit -m "feat: add JSONL storage module with retention cleanup"
```

---

## Task 3: Create Notifications API Module

**Files:**
- Create: `lib/utts/notifications.rb`

**Step 1: Write the Notifications API**

```ruby
# lib/utts/notifications.rb
# frozen_string_literal: true

require_relative 'notification'
require_relative 'storage'

module Utts
  module Notifications
    class << self
      def log(text:, caller: nil, agent: nil, voice: nil, metadata: {})
        notification = Notification.new(
          text: text,
          caller: caller,
          agent: agent,
          voice: voice,
          metadata: metadata
        )
        Storage.append(notification)
      end

      def list(limit: nil, since: nil, include_dismissed: false)
        Storage.list(limit: limit, since: since, include_dismissed: include_dismissed)
      end

      def find(id)
        Storage.find(id)
      end

      def dismiss(id)
        Storage.dismiss(id)
      end

      def dismiss_all
        Storage.dismiss_all
      end

      def replay(id)
        notification = find(id)
        return nil unless notification

        # Build utts command to replay
        cmd = ['utts', notification.text]
        cmd += ['--agent', notification.agent] if notification.agent
        cmd += ['--voice', notification.voice] if notification.voice && !notification.agent

        system(*cmd)
        notification
      end

      # Hook for integrations
      @on_activate_handler = nil

      def on_activate(&block)
        @on_activate_handler = block
      end

      def activate(id)
        notification = find(id)
        return nil unless notification

        if @on_activate_handler
          @on_activate_handler.call(notification)
        elsif notification.metadata && notification.metadata['action']
          execute_action(notification.metadata['action'])
        end

        notification
      end

      private

      def execute_action(action)
        return unless action.is_a?(Hash)

        case action['type']
        when 'shell'
          system(action['command']) if action['command']
        when 'url'
          system('open', action['url']) if action['url']
        end
      end
    end
  end
end
```

**Step 2: Commit**

```bash
git add lib/utts/notifications.rb
git commit -m "feat: add Notifications API module with replay and activate"
```

---

## Task 4: Create Main Entry Point

**Files:**
- Create: `lib/utts.rb`

**Step 1: Write the entry point**

```ruby
# lib/utts.rb
# frozen_string_literal: true

require_relative 'utts/notification'
require_relative 'utts/storage'
require_relative 'utts/notifications'

module Utts
  VERSION = '0.2.0'
end
```

**Step 2: Commit**

```bash
git add lib/utts.rb
git commit -m "feat: add main utts.rb entry point"
```

---

## Task 5: Add CLI Flags to bin/utts

**Files:**
- Modify: `bin/utts`

**Step 1: Add new option parsing**

After line 296 (after the `--rate` option), add:

```ruby
  opts.on('--caller CALLER', 'Caller identifier for notification logging') do |c|
    options[:caller] = c
  end

  opts.on('--metadata JSON', 'JSON metadata for notification') do |m|
    begin
      options[:metadata] = JSON.parse(m)
    rescue JSON::ParserError
      warn "Invalid JSON for --metadata"
      exit 1
    end
  end

  opts.on('--history [N]', Integer, 'Show last N notifications (default: 10)') do |n|
    options[:history] = n || 10
  end

  opts.on('--replay [ID]', 'Replay notification (most recent if no ID)') do |id|
    options[:replay] = id || :latest
  end

  opts.on('--silent', 'Log notification without audio or system notification') do
    options[:silent] = true
  end
```

**Step 2: Add notification logging helper function**

Before the `# --- Main ---` section (around line 268), add:

```ruby
# --- Notification Logging ---

def log_notification(message, options, voice)
  # Only log if notification system is available (Tier 3)
  notifications_lib = File.join(UTTS_DIR, 'lib', 'utts', 'notifications.rb')
  return unless File.exist?(notifications_lib)

  begin
    require notifications_lib
    Utts::Notifications.log(
      text: message,
      caller: options[:caller],
      agent: options[:agent],
      voice: voice,
      metadata: options[:metadata] || {}
    )
  rescue StandardError => e
    # Silent fail - don't break TTS if logging fails
    warn "Notification logging failed: #{e.message}" if ENV['UTTS_DEBUG']
  end
end

def show_history(limit)
  notifications_lib = File.join(UTTS_DIR, 'lib', 'utts', 'notifications.rb')
  unless File.exist?(notifications_lib)
    warn "Notification history requires Tier 3 (bundle install)"
    exit 1
  end

  require notifications_lib
  notifications = Utts::Notifications.list(limit: limit, include_dismissed: true)

  if notifications.empty?
    puts "No notifications in history"
    return
  end

  puts "Last #{[limit, notifications.size].min} notifications:\n\n"
  notifications.each do |n|
    time = Time.parse(n.timestamp).localtime.strftime('%b %d %H:%M')
    status = n.dismissed? ? '✓' : '○'
    caller_str = n.caller ? "  #{n.caller}" : ''
    puts "#{status} [#{n.id}] #{time}#{caller_str}"
    puts "  \"#{n.text}\""
    puts
  end
end

def replay_notification(id_or_latest)
  notifications_lib = File.join(UTTS_DIR, 'lib', 'utts', 'notifications.rb')
  unless File.exist?(notifications_lib)
    warn "Replay requires Tier 3 (bundle install)"
    exit 1
  end

  require notifications_lib

  if id_or_latest == :latest
    notifications = Utts::Notifications.list(limit: 1)
    if notifications.empty?
      warn "No notifications to replay"
      exit 1
    end
    notification = notifications.first
  else
    notification = Utts::Notifications.find(id_or_latest)
    unless notification
      warn "Notification not found: #{id_or_latest}"
      exit 1
    end
  end

  puts "Replaying: \"#{notification.text}\""
  Utts::Notifications.replay(notification.id)
end
```

**Step 3: Add command handlers after option parsing**

After the `parser.parse!` block (around line 341), add handlers for new options:

```ruby
# Handle --history
if options[:history]
  show_history(options[:history])
  exit 0
end

# Handle --replay
if options[:replay]
  replay_notification(options[:replay])
  exit 0
end
```

**Step 4: Add notification logging after speech**

At the end of the file, after the speech `case` statement (around line 394), add:

```ruby
# Log notification (if Tier 3 available and not silent)
unless options[:silent]
  log_notification(safe_message, options, voice)
end
```

**Step 5: Commit**

```bash
git add bin/utts
git commit -m "feat: add --caller, --metadata, --history, --replay, --silent flags"
```

---

## Task 6: Manual Testing

**Step 1: Test basic notification logging**

```bash
# Speak and log
./bin/utts "Test notification one" --caller "test-session"

# Check it was logged
cat ~/.config/utts/notifications.jsonl
```

Expected: One JSON line with the notification.

**Step 2: Test --history**

```bash
# Add a few more
./bin/utts "Test notification two" --caller "another-session"
./bin/utts "Test notification three"

# View history
./bin/utts --history
./bin/utts --history 2
```

Expected: Lists notifications in reverse chronological order.

**Step 3: Test --replay**

```bash
# Replay most recent
./bin/utts --replay

# Replay by ID (get ID from --history output)
./bin/utts --replay <id>
```

Expected: Re-speaks the notification.

**Step 4: Test --metadata**

```bash
./bin/utts "With action" --caller "test" --metadata '{"action":{"type":"shell","command":"echo hello"}}'
./bin/utts --history
```

Expected: Notification logged with metadata.

**Step 5: Test --silent**

```bash
./bin/utts "Silent test" --silent
./bin/utts --history
```

Expected: Speaks but does NOT log.

Wait - re-reading the design, `--silent` should log but not speak. Let me correct:

**Step 5 (corrected): Test --silent**

```bash
# First, verify silent doesn't speak
./bin/utts "Silent test" --silent --caller "silent-test"

# Should still be in history
./bin/utts --history
```

Expected: Does NOT speak, but IS logged.

**Step 6: Commit test results confirmation**

```bash
git add -A
git commit -m "chore: phase 1 complete - notification logging working"
```

---

## Summary

After completing these tasks, utts will have:
- ✅ `--caller` flag for caller identification
- ✅ `--metadata` flag for JSON metadata (including actions)
- ✅ `--history` command to view recent notifications
- ✅ `--replay` command to re-speak notifications
- ✅ `--silent` flag to suppress audio while still logging
- ✅ JSONL storage with 5-day retention
- ✅ Ruby API (`Utts::Notifications`) for programmatic access
