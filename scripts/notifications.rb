#!/usr/bin/env ruby
# frozen_string_literal: true

# utts Notification Dashboard (Tier 3 - Premium)
# StreamWeaver-based GUI for "Say That Again" feature

require 'bundler/setup'
require 'stream_weaver'
require 'fileutils'

# Load notification system
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
require 'utts'

SCRIPT_DIR = File.dirname(File.realpath(__FILE__))
UTTS_DIR = ENV.fetch('UTTS_DIR', File.expand_path('..', SCRIPT_DIR))
CONFIG_DIR = File.expand_path('~/.config/utts')
PID_FILE = File.join(CONFIG_DIR, 'notifications.pid')
URL_FILE = File.join(CONFIG_DIR, 'notifications.url')

def replay_notification(notification)
  pid = spawn("#{UTTS_DIR}/bin/utts", notification.text,
              '--voice', notification.voice || 'en_US-lessac-medium',
              '--caller', "replay: #{notification.caller || notification.id}")
  Process.detach(pid)
end

def format_time(timestamp)
  Time.parse(timestamp).localtime.strftime('%H:%M')
rescue
  timestamp
end

def format_date(timestamp)
  Time.parse(timestamp).localtime.strftime('%b %d')
rescue
  ''
end

def has_action?(notification)
  notification.metadata && notification.metadata['action']
end

def caller_display(notification)
  return nil unless notification.caller
  parts = notification.caller.split(':', 2)
  if parts.length == 2
    { project: parts[0].strip, intent: parts[1].strip }
  else
    { project: parts[0].strip, intent: nil }
  end
end

# Write PID file for smart launch
FileUtils.mkdir_p(CONFIG_DIR)
File.write(PID_FILE, Process.pid.to_s)

# Cleanup on exit
at_exit do
  FileUtils.rm_f(PID_FILE)
  FileUtils.rm_f(URL_FILE)
end

app "Voice Notifications", layout: :default, theme: :dashboard do
  toast_container position: :top_right, duration: 3000

  # Get notifications
  notifications = Utts::Notifications.list(limit: 50, include_dismissed: false)
  all_notifications = Utts::Notifications.list(limit: 50, include_dismissed: true)
  dismissed_count = all_notifications.count(&:dismissed?)

  # Header with stats and actions
  hstack justify: :between, align: :center do
    hstack spacing: :md, align: :center do
      header2 "Notifications"
      text "(#{notifications.size} active)"
    end

    hstack spacing: :sm do
      button "Refresh", style: :secondary do
        show_toast("Refreshed", variant: :info)
      end

      if notifications.any?
        button "Dismiss All", style: :secondary do
          Utts::Notifications.dismiss_all
          show_toast("All dismissed", variant: :success)
        end
      end
    end
  end

  md "---"

  # Active notifications
  if notifications.empty?
    vstack spacing: :lg do
      text ""
      alert(variant: :info) { text "No active notifications. You're all caught up!" }
    end
  else
    vstack spacing: :sm do
      notifications.each do |n|
        caller_info = caller_display(n)

        card do
          # Header row: time + caller info
          hstack justify: :between, align: :center do
            hstack spacing: :sm, align: :center do
              text format_time(n.timestamp)
              if caller_info
                md "**#{caller_info[:project]}**"
                if caller_info[:intent]
                  text caller_info[:intent]
                end
              end
            end
            text format_date(n.timestamp)
          end

          # Message - the main content
          vstack spacing: :xs do
            text n.text
          end

          # Action buttons
          hstack spacing: :sm do
            if has_action?(n)
              button "Go To", style: :primary do
                Utts::Notifications.activate(n.id)
                show_toast("Activated", variant: :success)
              end
            end

            button "Replay" do
              replay_notification(n)
              show_toast("Replaying...", variant: :info)
            end

            button "Dismiss", style: :secondary do
              Utts::Notifications.dismiss(n.id)
              show_toast("Dismissed", variant: :success)
            end
          end
        end
      end
    end
  end

  # Dismissed section (collapsible)
  if dismissed_count > 0
    md "---"
    collapsible "Dismissed (#{dismissed_count})" do
      vstack spacing: :xs do
        dismissed = all_notifications.select(&:dismissed?)
        dismissed.each do |n|
          caller_info = caller_display(n)

          hstack justify: :between, align: :center do
            hstack spacing: :sm, align: :center do
              text "✓"
              text format_time(n.timestamp)
              if caller_info
                text caller_info[:project]
              end
              text "\"#{n.text.truncate(40)}\""
            end

            button "Replay", style: :secondary do
              replay_notification(n)
              show_toast("Replaying...", variant: :info)
            end
          end
        end
      end
    end
  end
end.run!
