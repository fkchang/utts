# frozen_string_literal: true

module Utts
  module MacosNotifier
    TERMINAL_NOTIFIER = 'terminal-notifier'

    class << self
      def available?
        return @available if defined?(@available)

        @available = system("which #{TERMINAL_NOTIFIER} > /dev/null 2>&1")
      end

      def notify(text:, title: nil, subtitle: nil, sound: true, click_command: nil)
        return false unless available?

        cmd = [TERMINAL_NOTIFIER]
        cmd += ['-message', text]
        cmd += ['-title', title] if title
        cmd += ['-subtitle', subtitle] if subtitle
        cmd += ['-sound', 'default'] if sound
        cmd += ['-execute', click_command] if click_command
        cmd += ['-group', 'utts'] # Group notifications together
        cmd += ['-ignoreDnD'] # Show even in Do Not Disturb (optional)

        system(*cmd)
      end

      # Convenience method for utts notifications
      def send_notification(notification_text:, caller_name: nil, muted: false)
        return false unless available?

        title = caller_name || 'utts'

        # Build click command to open notification dashboard
        utts_bin = File.expand_path('../../../bin/utts', __FILE__)
        click_command = "#{utts_bin} --notifications"

        notify(
          text: notification_text,
          title: title,
          sound: !muted, # No sound when muted
          click_command: click_command
        )
      end
    end
  end
end
