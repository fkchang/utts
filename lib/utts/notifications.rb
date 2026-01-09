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

        # Find utts binary
        utts_bin = File.expand_path('../../../bin/utts', __FILE__)

        # Build utts command to replay (will re-log with "replay:" prefix)
        cmd = [utts_bin, notification.text]
        cmd += ['--agent', notification.agent] if notification.agent
        cmd += ['--voice', notification.voice] if notification.voice && !notification.agent
        cmd += ['--caller', "replay: #{notification.caller || notification.id}"]

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
