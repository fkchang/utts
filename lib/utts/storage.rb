# frozen_string_literal: true

require 'json'
require 'yaml'
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
